# This script has been tested on Debian 8 Jessie image
#
# chmod +x ./nginxStart.sh
#  ---------------------------------------------------------
if [ "$EUID" -ne 0 ]; then echo "Must be root"; exit; fi
LINE="-------------------------------------------------------"
#lineOrder="${@,,}"
echo $LINE$LINE
dockerImage='app2linux/nginx21ssl:latest'
echo 'Image: '$dockerImage

docker push $dockerImage

docker run -d --restart always --net=host -v /var/www:/var/www/ -v /app/nginx:/etc/nginx/conf.d/ --name nginx app2linux/nginx2ssl:latest
