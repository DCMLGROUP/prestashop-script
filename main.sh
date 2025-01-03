#!/bin/bash

# Source variables file
if [ -f "variables.sh" ]; then
    source variables.sh
else
    echo "Le fichier variables.sh est manquant. Veuillez le créer avec les variables requises."
    exit 1
fi

# Fonction pour détecter la distribution
detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        echo "Impossible de détecter la distribution"
        exit 1
    fi
}

# Installation des dépendances selon la distribution
install_dependencies() {
    case $OS in
        "Debian GNU/Linux"|"Ubuntu")
            apt update
            apt install -y apache2 php php-mysql php-gd php-xml php-curl \
                         libapache2-mod-php mariadb-server mariadb-client \
                         php-bcmath php-mbstring php-zip php-intl unzip
            ;;
        "Fedora")
            dnf update -y
            dnf install -y httpd php php-mysql php-gd php-xml php-curl \
                         mariadb-server mariadb php-bcmath php-mbstring \
                         php-zip php-intl unzip
            systemctl enable httpd
            systemctl start httpd
            ;;
        *)
            echo "Distribution non supportée"
            exit 1
            ;;
    esac
}

# Configuration de la base de données
configure_database() {
    systemctl start mariadb
    systemctl enable mariadb

    mysql -e "CREATE DATABASE prestashop CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    mysql -e "CREATE USER 'prestashop'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
    mysql -e "GRANT ALL PRIVILEGES ON prestashop.* TO 'prestashop'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
}

# Installation de PrestaShop
install_prestashop() {
    # Téléchargement de PrestaShop
    wget https://download.prestashop.com/download/releases/prestashop_1.7.8.8.zip -O prestashop.zip
    
    # Nettoyage du répertoire web
    rm -rf /var/www/html/*
    
    # Extraction de PrestaShop
    unzip prestashop.zip -d /var/www/html/
    unzip /var/www/html/prestashop.zip -d /var/www/html/
    rm /var/www/html/prestashop.zip
    rm /var/www/html/index.html
    
    # Configuration des permissions
    chown -R www-data:www-data /var/www/html/
    chmod -R 755 /var/www/html/
}

# Configuration du vhost Apache
configure_vhost() {
    cat > /etc/apache2/sites-available/prestashop.conf <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    DocumentRoot /var/www/html
    
    <Directory /var/www/html>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/prestashop-error.log
    CustomLog \${APACHE_LOG_DIR}/prestashop-access.log combined
</VirtualHost>
EOF

    a2ensite prestashop.conf
    a2enmod rewrite
    systemctl restart apache2
}

# Exécution principale
echo "Début de l'installation de PrestaShop..."

detect_distribution
install_dependencies
configure_database
install_prestashop
configure_vhost

echo "Installation et configuration terminées!"
echo "Vous pouvez maintenant accéder à PrestaShop via http://$DOMAIN_NAME"
echo "Veuillez compléter l'installation via l'interface web."
