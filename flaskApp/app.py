from flask import Flask, request, jsonify
import psycopg2
from psycopg2.extras import RealDictCursor
from azure.storage.blob import BlobServiceClient
import os
from dotenv import load_dotenv
import io
from flask import send_file

# Charger les variables d'environnement à partir du fichier .env
load_dotenv()

app = Flask(__name__)

# Connexion à PostgreSQL
try:
    conn = psycopg2.connect(
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        sslmode=os.getenv("DB_SSLMODE", "prefer"),
    )
    cursor = conn.cursor()
    print("Connexion à PostgreSQL réussie.")
except psycopg2.Error as e:
    print("Erreur de connexion à PostgreSQL :", e)
    exit(1)

# Vérifier et créer la table des utilisateurs et des fichiers si elles n'existent pas
with conn.cursor() as cursor:
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS files (
            id SERIAL PRIMARY KEY,
            filename TEXT NOT NULL,
            file_size INT NOT NULL,
            file_type TEXT NOT NULL,
            uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            user_id INT REFERENCES users(id)
        )
    """)
    conn.commit()
    print("Tables 'users' et 'files' vérifiées/créées avec succès.")

# Connexion à Azure Blob Storage
STORAGE_ACCOUNT_NAME = os.getenv("STORAGE_ACCOUNT_NAME")
STORAGE_ACCOUNT_KEY = os.getenv("STORAGE_ACCOUNT_KEY")
CONTAINER_NAME = os.getenv("CONTAINER_NAME")

blob_service_client = BlobServiceClient(
    f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net",
    credential=STORAGE_ACCOUNT_KEY
)

# Routes CRUD pour les utilisateurs
@app.route('/user', methods=['POST'])
def create_user():
    """Créer un utilisateur."""
    data = request.get_json()
    if not data or 'name' not in data or 'email' not in data:
        return jsonify({"error": "Missing name or email"}), 400

    try:
        with conn.cursor() as cursor:
            cursor.execute("INSERT INTO users (name, email) VALUES (%s, %s) RETURNING id", (data['name'], data['email']))
            user_id = cursor.fetchone()[0]
            conn.commit()
        return jsonify({"id": user_id, "message": "User created successfully"}), 201
    except psycopg2.Error as e:
        conn.rollback()
        return jsonify({"error": str(e)}), 500

@app.route('/user/<int:user_id>', methods=['GET'])
def get_user(user_id):
    """Lire un utilisateur par son Id."""
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if user:
            return jsonify(user), 200
        else:
            return jsonify({"message": "User not found"}), 404

@app.route('/user/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    """Mettre à jour un utilisateur."""
    data = request.get_json()
    if not data or 'name' not in data or 'email' not in data:
        return jsonify({"error": "Missing name or email"}), 400

    with conn.cursor() as cursor:
        cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        if cursor.fetchone() is None:
            return jsonify({"error": "User not found"}), 404

        cursor.execute("UPDATE users SET name = %s, email = %s WHERE id = %s", (data['name'], data['email'], user_id))
        conn.commit()
    return jsonify({"message": "User updated successfully"}), 200

@app.route('/user/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    """Supprimer un utilisateur."""
    with conn.cursor() as cursor:
        cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
        if cursor.fetchone() is None:
            return jsonify({"error": "User not found"}), 404

        cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
        conn.commit()
    return jsonify({"message": "User deleted successfully"}), 200

# Route pour lire tous les utilisateurs
@app.route('/users', methods=['GET'])
def read_users():
    """Lire tous les utilisateurs."""
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute("SELECT * FROM users")
        users = cursor.fetchall()
    return jsonify(users), 200

# Routes pour l'upload et download de fichiers vers Azure Blob Storage avec gestion des métadonnées
@app.route('/upload', methods=['POST'])
def upload_file():
    """Téléverser un fichier dans Azure Blob Storage et enregistrer les métadonnées."""
    if 'file' not in request.files:
        return jsonify({"error": "No file uploaded"}), 400

    file = request.files['file']
    user_id = request.form.get('user_id')  # Associer un utilisateur au fichier (facultatif)
    
    try:
        # Upload du fichier
        blob_client = blob_service_client.get_blob_client(container=CONTAINER_NAME, blob=file.filename)
        blob_client.upload_blob(file, overwrite=True)
        
        # Enregistrer les métadonnées dans la base de données
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO files (filename, file_size, file_type, user_id)
                VALUES (%s, %s, %s, %s) RETURNING id
            """, (file.filename, len(file.read()), file.content_type, user_id))
            file_id = cursor.fetchone()[0]
            conn.commit()

        return jsonify({"message": "File uploaded successfully", "file_id": file_id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/download/<filename>', methods=['GET'])
def download_file(filename):
    """Télécharger un fichier depuis Azure Blob Storage avec contrôle d'accès."""
    # Vérifier si l'utilisateur a le droit de télécharger ce fichier
    user_id = request.args.get('user_id')  # Récupérer l'ID utilisateur de la requête
    with conn.cursor() as cursor:
        cursor.execute("SELECT * FROM files WHERE filename = %s AND user_id = %s", (filename, user_id))
        file_metadata = cursor.fetchone()
        if not file_metadata:
            return jsonify({"error": "Unauthorized or file not found"}), 403

    blob_client = blob_service_client.get_blob_client(container=CONTAINER_NAME, blob=filename)
    
    try:
        # Vérifier si le fichier existe dans Blob Storage
        if not blob_client.exists():
            return jsonify({"error": "File not found"}), 404

        # Télécharger le fichier en mémoire
        stream = blob_client.download_blob()
        
        # Utiliser send_file pour renvoyer le fichier
        return send_file(
            io.BytesIO(stream.readall()),
            download_name=filename,
            as_attachment=True
        ), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
