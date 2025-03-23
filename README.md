
# Terraform Projet - Gestion des Machines Virtuelles Azure

## Prérequis

Avant de commencer, assurez-vous d'avoir les éléments suivants installés :

- [Terraform](https://www.terraform.io/downloads.html)
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) pour gérer les ressources sur Azure
- Un compte Azure actif et les bonnes autorisations pour gérer les ressources sur votre abonnement

## Initialisation du projet

Pour initialiser votre projet Terraform et installer les modules nécessaires, exécutez la commande suivante dans le répertoire racine de votre projet Terraform :

```bash
terraform init
```

## Appliquer les changements sur l'infrastructure

### Taint une ressource

Si vous souhaitez forcer la recréation d'une ressource spécifique, vous pouvez utiliser la commande `terraform taint`. Par exemple, pour marquer une machine virtuelle comme étant "altérée" et forcer sa reconstruction, utilisez la commande suivante :

```bash
terraform taint azurerm_linux_virtual_machine.vm
```

Cela marquera la ressource `azurerm_linux_virtual_machine.vm` pour la suppression et la recréation lors de la prochaine exécution de `terraform apply`.

### Appliquer les changements

Une fois que vous avez apporté des modifications à votre code Terraform ou après avoir fait un `terraform taint`, il est temps de mettre à jour l'infrastructure sur Azure. Exécutez la commande suivante pour appliquer les changements :

```bash
terraform apply
```

Cela va comparer l'état actuel de l'infrastructure avec le code Terraform et vous présenter un plan des changements à appliquer. Si vous êtes satisfait du plan, tapez `yes` pour que les changements soient effectivement appliqués.

### Gestion des changements Git

Si des modifications ont été poussées sur le dépôt Git distant, vous devez vous assurer que votre environnement local est à jour. Exécutez les commandes suivantes pour récupérer les dernières modifications :

```bash
git pull origin main  # ou la branche correspondante
```

Ensuite, exécutez la commande `terraform apply` pour appliquer les changements locaux en fonction du code mis à jour :

```bash
terraform apply
```

## Informations supplémentaires

- Si vous devez mettre à jour des variables ou des configurations d'infrastructure, modifiez les fichiers `.tf` et réexécutez `terraform apply`.
- Vous pouvez également vérifier l'état actuel de l'infrastructure avec la commande `terraform show`.

## Aide et Support

Si vous avez besoin d'aide, consultez la [documentation officielle de Terraform](https://www.terraform.io/docs).
