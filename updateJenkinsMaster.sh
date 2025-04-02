#!/bin/sh

git checkout master

git pull


new_version=$(curl -s https://api.github.com/repos/jenkinsci/jenkins/tags | jq -r '.[] | select (.name | contains("jenkins-")) | .name | sub("jenkins-";"") ' | sort -V | tail -1)


echo "New version is $new_version"
echo "Continue? enter for yes, anything else for no"
read check
if [ -n "$check" ]; then
 echo "Give new version"
 read new_version
fi

new_tag=$new_version
echo "New tag is $new_tag"
echo "Continue? enter for yes, anything else for no"
read check
if [ -n "$check" ]; then
 echo "Give new tag"
 read new_tag
fi

if [ $(grep $new_version"}" Dockerfile | wc -l ) -eq 1 ]; then
	echo "Version $new_version is already in Dockerfile, skipping"
else


  JENKINS_VERSION=$new_version

  if [ ! -f jenkins-war-${JENKINS_VERSION}.war ]; then
	wget https://repo.jenkins-ci.org/public/org/jenkins-ci/main/jenkins-war/${JENKINS_VERSION}/jenkins-war-${JENKINS_VERSION}.war
  fi

  sha=$(sha256sum jenkins-war-${JENKINS_VERSION}.war | awk '{print $1}')

  sed -i "s/ENV JENKINS_VERSION.*/ENV JENKINS_VERSION \$\{JENKINS_VERSION:\-$new_version\}/" Dockerfile
  sed -i "s/ARG JENKINS_SHA=.*/ARG JENKINS_SHA=$sha/" Dockerfile


  git diff | more
  echo "continue? git commit ( enter for yes)"
   read check
   if [ -z "$check" ]; then
    git add Dockerfile
    rm jenkins-war-${JENKINS_VERSION}.war
   fi

fi

if [ $(grep -c $new_tag/Dockerfile Readme.md) -eq 0 ]; then
sed -i "s|.*eea.docker.jenkins.master/blob/[0-9].*|\- [\`:$new_tag\` (*Dockerfile*)](https://github.com/eea/eea.docker.jenkins.master/blob/$new_tag/Dockerfile)|" Readme.md
fi

echo "-----------------------------------------------------------------"
echo "You need to have rancher client installed"
echo "Did you run rancher config to set to the correct environment ?"
echo "-----------------------------------------------------------------"

container_list=$(rancher ps -c -a | grep jenkins-master-master | grep healthy )
container_id=$(echo $container_list	| awk '{print $1}')
container_host=$(echo $container_list | awk '{print $5}')
container_name=$(echo $container_list | awk '{print $7}')


BACKUP_CREATED=${BACKUP_CREATED:-60}

echo "Jenkins ThinBackup created in the last $BACKUP_CREATED minutes ? Remember to wait 15 minutes for the plugins list to be updated"
echo "Continue? enter for yes, anything else for no"
read check
if [ -n "$check" ]; then
 echo "Give new time in minutes"
 read BACKUP_CREATED
fi

rancher exec jenkins-master-master-1 /bin/bash -c "ls -ltr /var/jenkins_home/backup/jenkins"

rancher exec jenkins-master-master-1 /bin/bash -c "find /var/jenkins_home/backup/jenkins/ -maxdepth 2 -type f -name installedPlugins.xml | xargs ls -ltr"

file_location=$(rancher exec jenkins-master-master-1 /bin/bash -c "find /var/jenkins_home/backup/jenkins/ -maxdepth 2 -mmin -$BACKUP_CREATED -type f -name installedPlugins.xml" | sed 's/installedPlugins.xml.*/installedPlugins.xml/' | head -n 1 )

if [ $(echo $file_location | grep installed | wc -l) -ne 1 ]; then
	echo "Not found recent plugins file, check command"
	echo $file_location
	exit 1
fi

rancher --host $container_host docker cp $container_name:$file_location .

if [ $? -ne 0 ]; then
        echo "rancher --host $container_host docker cp $container_name:$file_location ."
	echo "Could not copy file"
	exit 1;
fi

echo "Retrieved plugins backup, will now run python script"
python plugins.py

if [ $? -ne 0 ]; then
        echo "Could not process file"
        exit 1;
fi


git diff | more
echo "continue? git add ( enter for yes)"
 read check
 if [ -z "$check" ]; then
  git add plugins.txt
  rm installedPlugins.xml
 fi




if [ $(grep -c "## $new_tag " CHANGELOG.md) -eq 0 ]; then
echo "Adding new changelog"
echo "------------------------------------------------------------------------------------"
block="## $new_tag ($(date +%F))\n\n- Upgrade to jenkins $new_version\n- Upgrade plugins\n"
echo $block 
echo "Continue? enter for yes, anything else for no"
read check
if [ -n "$check" ]; then
 echo "Give new changelog"
 read block
fi
sed -i "3 i $block" CHANGELOG.md
fi

git diff | more
git status
if [ $( git diff | wc -l ) -ne 0 ]; then
 echo "continue? git commit"
 read check
 if [ -z "$check" ]; then
  git add CHANGELOG.md Readme.md Dockerfile plugins.txt
  git commit -m "Upgrade to jenkins $new_version"
  git push
 fi
fi

if [ $( git tag | grep -c $new_tag ) -eq 0 ]; then

 echo "continue? git tag"
 read check
 if [ -z "$check" ]; then
  git tag -a $new_tag -m $new_tag
  git push origin $new_tag
 fi
fi



