#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/silverlight-detect.git && cd silverlight-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

wget -t 1 -c -q -nv --user-agent="Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; .NET4.0C; .NET4.0E)" http://www.microsoft.com/getsilverlight/handlers/getsilverlight.ashx -S -o $tmp/silverlight.log

x86=$(sed "s/http/\nhttp/g" $tmp/silverlight.log | sed "s/\.exe/\.exe\n/g" | grep "^http.*\.exe")
x64=$(echo $x86 | sed "s/\.exe/_x64\.exe/g")

#create a new array [linklist] with two internet links inside and add one extra line
linklist=$(cat <<EOF
`echo $x86`
`echo $x64`
extra line
EOF
)


printf %s "$linklist" | while IFS= read -r url
do {
filename=$(echo $url | sed "s/^.*\///g")

echo Downloading $url
wget $url -O $tmp/$filename -q
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

#check if this file is already in database
grep "$sha1" $db > /dev/null
if [ $? -ne 0 ]
#if sha1 sum do not exist in database then this is new version
then
echo new version detected!
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

#lets put all signs about this file into the database
echo "$md5">> $db
echo "$sha1">> $db
			
echo searching exact version number

7z x $tmp/$filename -y -o$tmp > /dev/null
7z x $tmp/silverlight.7z -y -o$tmp > /dev/null
7z x $tmp/Silverlight.msp -y -o$tmp > /dev/null

version=$(sed "s/[a-zA-Z\/\s\?]/\n/g" $tmp/\!_StringData | awk "/./" | tail -1)
echo $version
echo

#create unique filename for google upload
newfilename=$(echo $filename | sed "s/\.exe/_`echo $version`\.exe/")
mv $tmp/$filename $tmp/$newfilename

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $newfilename to Google Drive..
echo Make sure you have created \"$appname\" directory inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$newfilename"
echo
fi

							#lets send emails to all people in "posting" file
							emails=$(cat ../posting | sed '$aend of file')
							printf %s "$emails" | while IFS= read -r onemail
							do {
								python ../send-email.py "$onemail" "$filename $version" "$url
$md5
$sha1"
							} done
							echo

fi

} done

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
