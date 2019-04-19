#!/bin/bash
# This script has been tested on Debian 8 Jessie image
# chmod +x ./letsencrypt.sh
#  ---------------------------------------------------------
if [ "$EUID" -ne 0 ]; then echo "Must be root"; exit; fi
#  ---------------------------------------------------------
LINE="---------------------------------------"
lineOrder="${@} "
#  ---------------------------------------------------------
echo
echo $LINE$LINE
echo -e "\nStart download SSL Letsencrypt for a Nginx Docker server."
echo $LINE
#  ---------------------------------------------------------
function isOk(){
echo -en "  ::  It's OK?  >  "; 
while IFS= read -rsn1 key; do
    [[ $key =~ ^[YySs]$ ]] && return 1
    [[ $key =~ ^[Nn]$ ]] && return 0
    done
return 1
}
#  ---------------------------------------------------------
echo -e 'Download Letsencrypt certificates ...\n\n'$LINE
ssl=$(sed -e '/^export SSL=/ !d' context.sh)
[[ ${ssl:11:1} == '"' || ${ssl:11:1} == "'" ]] && ssl=${ssl:12:-1} || ssl=${ssl:11}
if [ ! -z $ssl ]; then
    echo -e "\n\nSSL/TLS already configured with $ssl\n\n"$LINE 
    echo -en "\t"; read -rsn1 -p "Press a key to continue  >  " key; exit;
fi
source ./context.sh
domains=''
for ((i=1; i<${#context[@]}; i++)); do
    data=(${context[i]:1:-1})
    [[ -z $data || $data == "''" ]] && break
    domains+=${data[0]}","
    done
echo -en "Domains:\n\t{"$domains"}"
if [ -z $domains ]; then
    echo -e "\nNo domains to include into certificate\n"$LINE 
    echo -en "\t"; read -rsn1 -p "Press a key to continue  >  " key; exit;
fi
domains+='www.'$mainDomain
#
clear
echo -e "\n"$LINE$LINE"\nDefine LetsEncrypt options:\n"$LINE 
echo "    [<myEmail>] [auto] [sslOff]"
echo
echo "LetsEncrypt registration email is optional"
echo "[auto] Autorenew certificate"
echo "[sslOff] Download ssl certificate but do not web configure"
echo "All domains are included in certificate"
echo "    {"$domains"}"
echo -e "\n    [x]  Continue without ssl config"
echo -e $LINE 
read -p "   > " lineOrder
lineOrder=" "${lineOrder,,}" "
[[ $lineOrder == *" x "* || $lineOrder == *" c "* ]] && { clear; exit; }
[[ $lineOrder == *" auto "* ]] && autoRenew=1 || autoRenew=0
if [[ ${lineOrder} = " "*"@"*" " ]]; then 
    email1=${lineOrder%@* };email1=${email1##* }; 
    email=${lineOrder//*@/}; email=$email1@${email// */};
    if [[ ! "$email" =~ [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4} ]]; then
        echo -e "\nIncorrect email format\n\n"$LINE 
        echo -en "\t"; read -rsn1 -p "Press a key to continue  >  " key; exit;
    fi
else
    email=''
fi
echo -en "\n"$LINE"\nDomains: {"$domains"}\n  eMail: <"$email">\n"
[[ $autoRenew == 1 ]] && echo -e "Autorenew certificate. \n\tTesting all weeks." || echo -e "Manual renewal of certificates. \n\tNotice by email."
echo -en $LINE"\nCertificate data"
isOk; val=$?; [[ $val == 0 ]] && exit
#  ---------------------------------------------------------
# installa certificat
[[ ! -f ./certbot-auto ]] &&  { wget https://dl.eff.org/certbot-auto -P ./; chmod +x ./certbot-auto; }
[[ ! -f ./letsencrypt-auto ]] && { wget https://github.com/certbot/certbot/raw/master/letsencrypt-auto -P ./; chmod +x ./letsencrypt-auto; }
if [[ -d /etc/letsencrypt/live ]]; then
    echo -e "\nLetsEncrypt certificates already configured\n\n"$LINE
    read -rsn1 -p "Press any key to continue > "; exit 0;
fi
file='/etc/letsencrypt/cli.ini'
mkdir /etc/letsencrypt
echo -e "\n\n"$file 'content\n'$LINE
content="rsa-key-size = 4096"
[[ ${email} ]] && content+="\nemail = "$email || content+="\n#email = "
content+="\npreferred-challenges = http-01\nagree-tos = True\nrenew-by-default = True\n"
content+="domains = "$domains
echo -e $content
echo $LINE$LINE
echo -e "\nStarting install LetsEncrypt certificate ..."
echo -e $content > $file
echo $LINE
docker stop nginx
#./letsencrypt-auto certonly --standalone
./certbot-auto certonly --standalone
echo
if [[ -d /etc/letsencrypt/live ]]; then
    temp='export SSL="letsencrypt"'
    echo $temp
    sed -Ei "s/^export SSL=.*$/$temp/g" context.sh
    temp='export SSLemail="'${email}'"'
    echo $temp
    sed -Ei "s/^export SSLemail=.*$/$temp/g" context.sh
    temp='export SSLdomains="'$domainList'"'
    echo $temp
    sed -Ei "s/^export SSLdomains.*$/$temp/g" context.sh
fi
[[ ${lineOrder} = *"ssloff"* ]] && echo 'ssl not configured on domains' || ./sslConfig.sh
if [[ $autoRenew == 1 ]]; then
    crontab -l > mycron
    [[ ! $(sed -e '/certbot-auto/ !d' mycron) ]] && echo "45 2 * * 6 /root/.startup/certbot-auto renew && cp /etc/letsencrypt/live/$mainDomain/*.* /app/nginx/letsencrypt && docker restart $dockerNginxContainer" >> mycron
    crontab mycron
    rm mycron
    echo 'Added weekly task to cron'
fi
#
docker start nginx
echo -en "\n\n"$LINE"\n\t"
read -rsn1 -p "Press any key to continue > "
exit 0
