#!/bin/bash
#note:
#1.you should install sdat2img,make_ext4fs,rimg2sdat and etc files
#2.you should put the cm-*-dior.zip,del_app.txt,del_lib.txt,del_priv-app.txt and makesimplifiedzippackage.sh,
#totaling five files,in the same directory,then run this script as root
################################################################################
#some tokens
buildtag='1'
timeinf=$(date +%d_%b_%Y-%H_%M_%S)
builddate=${timeinf}
tags='229'
cpath=$(cd $(dirname $0); pwd)'/'
temp='/tmp/'
appdelf="${cpath}del_app.txt"
libdelf="${cpath}del_lib.txt"
privappdelf="${cpath}del_priv-app.txt"
targetzip=${cpath}"cm_${tags}_${builddate}_${buildtag}.zip"
clear
################################################################################
#show on the screen and write to the log file
#logfile
logfile=${cpath}"229_${timeinf}.log"
fifofile=${temp}"229_${timeinf}.fifo"
touch ${logfile}
mkfifo ${fifofile}
cat ${fifofile} | tee ${logfile} &
exec &> ${fifofile}
################################################################################
echo "################################################################################"
echo "note:"
echo "1.you should install sdat2img,make_ext4fs,rimg2sdat and etc files"
echo "2.you should put the cm-*-dior.zip,del_app.txt,del_lib.txt,del_priv-app.txt and makesimplifiedzippackage.sh,"
echo "totaling five files,in the same directory,then run this script as root"
echo "################################################################################"
#warning
which sdat2img &> /dev/null
if [ $? -ne 0 ]; then echo "No found sdat2img!!"; exit 1; fi
which make_ext4fs &> /dev/null
if [ $? -ne 0 ]; then echo "No found make_ext4fs!!"; exit 1; fi
which rimg2sdat &> /dev/null
if [ $? -ne 0 ]; then echo "No found rimg2sdat!!"; exit 1; fi
if [ ! -f ${cpath}cm-*-dior.zip ]; then echo "No CyanogenMod android zip package!!"; exit 1; fi
if [ ! -f ${appdelf} ]; then echo "No deleting app file list!!"; exit 1; fi
if [ ! -f ${libdelf} ]; then echo "No deleting lib file list!!"; exit 1; fi
if [ ! -f ${privappdelf} ]; then echo "No deleting priv-app file list!!"; exit 1; fi
#some temporary directories and temporary files
workfold=$(mktemp -d -p ${cpath} workfoldXXXXXX )'/'
bakfold=$(mktemp -d -p ${cpath}  bakfoldXXXXXX )'/'
ttemp=$(mktemp -d -p ${cpath} ttempXXXXXX )'/'
deldir=$(mktemp -d -p ${cpath} delfoldXXXXXX )'/'
delappdir=$(mktemp -d -p ${deldir} app_delXXXXXX )'/'
dellibdir=$(mktemp -d -p ${deldir} lib_delXXXXXX )'/'
delprivappdir=$(mktemp -d -p ${deldir} priv-app_delXXXXXX )'/'
oriimg=${bakfold}'ori_image.img'
outimg=${cpath}'sparse_simplified.img'
#step 1
#initial
orizip=$(ls ${cpath}cm-*dior.zip)
echo "0  now unzipping the file ${orizip} ..."
unzip ${orizip} -d ${workfold}
#1.remove the signed files
rm ${workfold}META-INF/*.*
echo "1.1 the sign information has been removed."
#2.save some  original files
mv ${workfold}'system.transfer.list' ${workfold}'system.new.dat'  ${bakfold}
cp ${workfold}'file_contexts' ${bakfold}
echo "1.2 system.transfer.list,system.new.dat,file_contexts have been saved to ${bakfold}."
#3.modify updater-script
#remove range_sha1 check code
uf=${workfold}'META-INF/com/google/android/updater-script'
stk="range_sha1"
etk="endif;"
rangestep=8
s=$(echo $(awk "/${stk}/{print FNR}" ${uf}) | awk '{print $1}')
e=$[${s} + ${rangestep}]
el=$(sed -n "${e}p" ${uf})
if [ ${el} = ${etk} ]
then
#bakup the original updater-script
	cp ${uf} ${bakfold}
	sed -i "${s},${e}d" ${uf}
#bakup the modified updater-script
	cp ${uf} ${bakfold}'updater-script_modified'
	echo "1.3 ${uf} has been modified."
	echo "  ${uf} has been saved to ${bakfold}"
else
	echo "1.3 something went wrong ..."
	echo "  please modify ${uf} by your hand ...."
fi
#4.convert sparse dat file to regular image file
sdat2img  ${bakfold}'system.transfer.list' ${bakfold}'system.new.dat' ${oriimg}
echo "1.4 system.new.dat has been converted to regular image file."
#5.mount the generated image file
echo "1.5 mount the converted regular image file ..."
mount -t ext4 -o loop  ${oriimg}  ${ttemp}
#step 2
#remove some apps and relevant
cat ${appdelf} | while read folds
do
	mv -v ${ttemp}'app/'${folds} ${delappdir}
done
echo "2.1 apps in ${appdelf} have been deleted from the target."
cat ${libdelf} | while read folds
do
	mv -v ${ttemp}'lib/'${folds} ${dellibdir}
done
echo "2.2 lib files in ${dellibdir} have been deleted from the target."
cat ${privappdelf} | while read folds
do
	mv -v ${ttemp}'priv-app/'${folds} ${delprivappdir}
done
echo "2.3 priv-apps in ${delprivappdir} have been deleted from the target."
#step 3
#modify the build.prop
buildpropf=${ttemp}'build.prop'
cp ${buildpropf} ${bakfold}
echo "3.1 the original build.prop has been backuped."
#1.remove the empty lines of head
sed  -i '/./,$ !d' ${buildpropf}
#2.change build user name
sed  -i "/build.user/{s/=[[:alpha:]]*/=${tags}/}" ${buildpropf}
#3.change build host name
sed  -i "/build.host/{s/=[[:alpha:]]*/=${tags}/}" ${buildpropf}
#4.change product name
sed  -i "/product.name/{s/dior/${tags}/}" ${buildpropf}
#5.change locale
sed  -i "/locale/{s/US/UK/}" ${buildpropf}
#6.change device name
sed  -i "/cm.device/{s/dior/${tags}/}" ${buildpropf}
#7.change camera settings
sed  -i "/camera2/{s/1/0/}" ${buildpropf}
#8.modify date format
sed  -i "/dateformat/{s/MM-dd-yyyy/dd-MM-yyyy/}" ${buildpropf}
#9.change notification sound
sed  -i "/notification_sound/{s/=[[:alpha:]]*\.ogg/=Rhea\.ogg/}" ${buildpropf}
#10.change alarm alert sound
sed  -i "/alarm_alert/{s/=[[:alpha:]]*\.ogg/=tsinghua\.ogg/}" ${buildpropf}
#11.change ringtone sound
sed  -i "/ringtone/{s/=[[:alpha:]]*\.ogg/=hmyx_pal4\.ogg/}" ${buildpropf}
#12.change bt name
sed  -i "/bt.name/{s/Android/${tags}/}" ${buildpropf}
#13.append network hostname in dhcp
sed  -i "/bt.name/a\
net.hostname=${tags}" ${buildpropf}
#remove the existed build.prop file
rm ${workfold}'system/build.prop'
cp ${buildpropf} ${workfold}'system/'
cp ${buildpropf} ${bakfold}'build.prop_modified'
echo "3.2 ${buildpropf} has been modified."
cat ${buildpropf}
#step 4
#copy some sound files to media
inalarmfp='/media/sda7/phone/ROMDIY/media/alarms/'
innotificationfp='/media/sda7/phone/ROMDIY/media/notifications/'
inringtonefp='/media/sda7/phone/ROMDIY/media/ringtones/'
outalarmfp=${ttemp}'media/audio/alarms/'
outnotificationfp=${ttemp}'media/audio/notifications/'
outringtonefp=${ttemp}'media/audio/ringtones/'
cp -r ${inalarmfp}*.*  ${outalarmfp}
cp -r ${innotificationfp}*.*  ${outnotificationfp}
cp -r ${inringtonefp}*.*  ${outringtonefp}
chmod 644 ${outalarmfp}*.*
chmod 644 ${outnotificationfp}*.*
chmod 644 ${outringtonefp}*.*
echo "4 some alarms,notifications,ringtons have been added to the target."
#step 5
#config vim
inpablofp='/usr/share/vim/vim74/colors/'
incolorfp='/media/sdb1/sysbak/vimConfigure/'
inaspfp='/media/sdb1/sysbak/vimConfigure/asy/'
insyntaxfp='/media/sdb1/sysbak/vimConfigure/'
infontfp='/media/sdb1/sysbak/fonts/usedfonts/'
outcolorsfp=${ttemp}'usr/share/vim/colors/'
outsyntaxfp=${ttemp}'usr/share/vim/syntax/'
outfontfp=${ttemp}'fonts/'
#1.config color
cp ${inpablofp}'pablo.vim' ${outcolorsfp}
cp ${incolorfp}'delek_DarkGrey.vim' ${outcolorsfp}
chmod 644 ${outcolorsfp}*.*
echo "5.1 pablo.vim and delek_DarkGrey.vim have been added to ${outcolorsfp}."
#2.config syntax
cp ${inaspfp}'asy.vim' ${outsyntaxfp}
cp ${insyntaxfp}'tex.vim' ${outsyntaxfp}
cp ${insyntaxfp}'pascal.vim' ${outsyntaxfp}
chmod 644 ${outsyntaxfp}*.*
echo "5.2 asy.vim,tex.vim and pascal.vim have been added to ${outsyntaxfp}."
#3.config fonts
cp ${infontfp}*.otf  ${outfontfp}
cp ${infontfp}*.ttf  ${outfontfp}
chmod 644 ${outfontfp}*.*
echo "5.3 Adobe fonts,times fonts and SourceCodePro fonts have been added to ${outfontfp}."
#step 6
#generate sparse dat files
cd ${ttemp}
chown -R root:root  ./*
rm -rf ./'lost+found/'
cd ${cpath}
#generate the Android sparse image
#could use :img2sdat ${outimg} ${cpath}
#to convert it the sparse dat files,and need add  "system" before the names
#make_ext4fs -S ${bakfold}'file_contexts' -s  -l 800M -a system  ${outimg}  ${ttemp}
#
#generate the Android regular image
make_ext4fs -S ${bakfold}'file_contexts'  -l 800M -a system  ${outimg}  ${ttemp}
rimg2sdat ${outimg}
echo "6 android sparse dat file has been generated."
#step 7
#generate the target android zip package
#the package is not signed,if need signing,should install jdk and signapk.jar,then run like,as same as apk files:
#java -jar signapk.jar -testkey.x509.pem testkey.pk8  XXXX.zip  XXXX_signed.zip
echo "7.1 moving generated system.transfer.list and system.new.dat to ${workfold} ..."
mv ${cpath}'system.transfer.list' ${cpath}'system.new.dat'  ${workfold}
cd ${workfold}
chown -R root:root ./*
echo "7.2 zipping the ${targetzip} file ..."
zip -b ${cpath} -r -9  ${targetzip}  ./*
chmod 644 ${targetzip}
chown 000:000 ${targetzip}
cd ${cpath}
#step 8
#clear the stage
#add # to the front of the line to save some files
echo "8 now clear any temporary directories and files ..."
echo "  you can add # to the front of the line to save some files"
rm ${outimg}
umount ${ttemp}
rmdir ${ttemp}
rm -rf ${workfold}
rm -rf ${bakfold}
rm -rf ${deldir}
echo "################################################################################"
echo "successfully created ${targetzip} !!"
echo "[32m     total time is [31m${SECONDS}[32m seconds.[0m"
echo "you could see the ${logfile} for further details."
echo "################################################################################"
#filter out some ANSI series and other characters in the log file
sed -i "s/\[[0-9]*m//g" ${logfile}
sed -i "s/\[[0-9]*\;[0-9]*m//g" ${logfile}
sed -i "s/^[\ \t]//g" ${logfile}
sed -i "s/[\ \t]*$//g" ${logfile}
################################################################################
