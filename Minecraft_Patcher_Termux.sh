#!/bin/zsh

#Patches to be applied (1 to apply and 0 to not apply)
nether_roof_limit_to_256=1
materialbinloader=1

#Links to Download
link_apkeditor=https://github.com/REAndroid/APKEditor/releases/download/V1.3.6/APKEditor-1.3.6.jar
link_materialbinloader_arm32_so_file=https://github.com/ddf8196/MaterialBinLoader/releases/download/6/libmaterialbinloader-arm.so
link_materialbinloader_arm64_so_file=https://github.com/ddf8196/MaterialBinLoader/releases/download/6/libmaterialbinloader-arm64.so

#APK key passwords
keystore=ctayuis1278e91jf
keypass=ctayuis1278e91jf

minecraft_zip_file=$1

dependences=("java" "wget" "sed" "apksigner")

mkdir -p ~/tmp

function check_dependences  {
    for cmd in "${dependences[@]}"; do
        if [[ ! $(which "$cmd") ]]; then
            echo "$cmd was not found"
            exit 1
        fi
    done
}

function generate_apk_key  {
    keytool -genkey \
    -noprompt \
    -v \
    -keystore ~/tmp/debug.keystore \
    -storepass $keystore \
    -keypass $keypass \
    -alias signkey \
    -keyalg RSA \
    -keysize 2048 \
    -validity 20000 \
    -dname "CN=unknown, OU=unknown, O=unknown, L=unknown, S=unknown, C=unknown"
}


function nether_roof_arm64 {
local old_hex="FF1F0039E50300910310A052"
local new_hex="FF1F0039E50300910320A052"

local old_hex_formatted=$(echo -n "$old_hex" | sed 's/../\\x&/g')
local new_hex_formatted=$(echo -n "$new_hex" | sed 's/../\\x&/g')

sed -i "s/$old_hex_formatted/$new_hex_formatted/g" ~/tmp/decompiled_minecraft/root/lib/arm64-v8a/libminecraftpe.so
}

function nether_roof_arm32 {

local old_hex="CDE900201A4620464FF40003"
local new_hex="CDE900201A4620464FF08073"

local old_hex_formatted=$(echo -n "$old_hex" | sed 's/../\\x&/g')
local new_hex_formatted=$(echo -n "$new_hex" | sed 's/../\\x&/g')

sed -i "s/$old_hex_formatted/$new_hex_formatted/g" ~/tmp/decompiled_minecraft/root/lib/armeabi-v7a/libminecraftpe.so

}

function nether_roof_patch {
    local sucess_test="0"
    local sucess_test_arm32="0"
    local sucess_test_arm64="0"

    [ -d ~/tmp/decompiled_minecraft/root/lib/arm64-v8a   ]   &&  nether_roof_arm64  &&   sucess_test="1"  sucess_test_arm64="1"
    [ -d ~/tmp/decompiled_minecraft/root/lib/armeabi-v7a ]   &&  nether_roof_arm32  &&   sucess_test="1"  sucess_test_arm32="1"
    [ $sucess_test -eq 1 ] && echo "\e[36m""Nether_roof_patch:""\e[0m""Patch applied"
    [ $sucess_test_arm32 -eq 1 ]    &&   echo "                 \e[0m"" ↳ (ARM_32)"
    [ $sucess_test_arm64 -eq 1 ]    &&   echo "                 \e[0m"" ↳ (ARM_64)"
    [ $sucess_test -eq 0 ] && echo "\e[36m""Nether_roof_patch:""\e[0m""\e[31m""Error - Patch not applied""\e[0m"
}


function materialbinloader_arm64 {
cd ~/tmp/decompiled_minecraft/root/lib/arm64-v8a/
echo "\e[32m""Downloading materialbinloader-arm64.so""\e[0m"
wget -q --show-progress -O libmaterialbinloader-arm64.so $link_materialbinloader_arm64_so_file
# cp ~/storage/shared/Editor/libmaterialbinloader-arm64.so ~/tmp/decompiled_minecraft/root/lib/armeabi-v7a/libmaterialbinloader-arm64.so
patchelf --add-needed libmaterialbinloader-arm64.so libminecraftpe.so
cd ~/
}

function materialbinloader_arm32 {
cd ~/tmp/decompiled_minecraft/root/lib/armeabi-v7a/
echo "\e[32m""Downloading materialbinloader-arm32.so""\e[0m"
wget -q --show-progress -O libmaterialbinloader-arm32.so $link_materialbinloader_arm32_so_file
# cp ~/storage/shared/Editor/libmaterialbinloader-arm.so ~/tmp/decompiled_minecraft/root/lib/armeabi-v7a/libmaterialbinloader-arm32.so
patchelf --add-needed libmaterialbinloader-arm32.so armeabi-v7a/libminecraftpe.so
cd ~/
}

function materialbinloader_patch {
    local dependences=("patchelf")
    check_dependences

    local sucess_test="0"
    local sucess_test_arm32="0"
    local sucess_test_arm64="0"

    [ -d ~/tmp/decompiled_minecraft/root/lib/arm64-v8a   ]   &&  materialbinloader_arm64  &&   sucess_test="1"  sucess_test_arm64="1"
    [ -d ~/tmp/decompiled_minecraft/root/lib/armeabi-v7a ]   &&  materialbinloader_arm32  &&   sucess_test="1"  sucess_test_arm32="1"
    [ $sucess_test -eq 1 ]  && echo "\e[36m""Materialbinloader_patch:""\e[0m""Patch applied"
    [ $sucess_test_arm32 -eq 1 ]   &&  echo "                        ""\e[0m"" ↳ (ARM_32)"
    [ $sucess_test_arm64 -eq 1 ]   &&  echo "                        ""\e[0m"" ↳ (ARM_64)"
    [ $sucess_test -eq 0 ]  && echo "\e[36m""Materialbinloader_patch:""\e[0m""\e[31m""Error - Patch not applied""\e[0m"
}


function clear_tmp {
    rm -f ~/tmp/debug.keystore
    rm -f ~/tmp/Minecraft-merged.apk
    rm -f ~/tmp/APKEditor.jar
    rm -rf ~/tmp/decompiled_minecraft
}


function aply_patches {
    cd ~/
    [ $nether_roof_limit_to_256 -eq 1 ]  &&   nether_roof_patch
    [ $materialbinloader -eq 1 ]         &&   materialbinloader_patch
}


echo "Downloading APKEditor"
wget -q --show-progress -O ~/tmp/APKEditor.jar $link_apkeditor

check_dependences
generate_apk_key

java -jar ~/tmp/APKEditor.jar m -i $minecraft_zip_file -o ~/tmp/Minecraft-merged.apk &&\
mkdir  -p ~/tmp/decompiled_minecraft
java -jar ~/tmp/APKEditor.jar d -i ~/tmp/Minecraft-merged.apk -o ~/tmp/decompiled_minecraft &&\

aply_patches

java -jar ~/tmp/APKEditor.jar b -i ~/tmp/decompiled_minecraft -o ~/minecraft_modded.apk &&\
apksigner sign --ks ~/tmp/debug.keystore --ks-key-alias signkey --ks-pass pass:$keystore --key-pass pass:$keypass ~/minecraft_modded.apk\
&& clear_tmp
