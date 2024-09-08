#!/bin/zsh

#Patches to be applied (1 to apply and 0 to not apply)
nether_roof_limit_to_256=1
materialbinloader=0

#Links to Download
link_apkeditor=https://github.com/REAndroid/APKEditor/releases/download/V1.3.9/APKEditor-1.3.9.jar
link_uber_apk_signer=https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar
link_materialbinloader_arm32_so_file=https://github.com/ddf8196/MaterialBinLoader/releases/download/6/libmaterialbinloader-arm.so
link_materialbinloader_arm64_so_file=https://github.com/ddf8196/MaterialBinLoader/releases/download/6/libmaterialbinloader-arm64.so

#APK key passwords
keystore=ctayuis1278e91jf
keypass=ctayuis1278e91jf

apk_key_path=~/tmp/debug.keystore
output_apk_folder=$HOME/tmp/output
output_apk_name=minecraft_modded.apk
mkdir -p $output_apk_folder

minecraft_apk_files=$1  # .zip or folder with the apks

dependences=("java" "wget" "sed" "adb")
dependences_termux=("java" "wget" "sed" "apksigner")

mkdir -p ~/tmp

function check_dependences  {
    [[ $(uname -o) == Android ]] && dependences=("${dependences_termux[@]}")
    for cmd in "${dependences[@]}"; do
        if [[ ! $(command -v "$cmd") ]]; then
            echo "$cmd was not found"
            exit 1
        fi
    done
}

function check_input_files {
    local input_error=0
    local is_not_a_dir=0
    local is_not_a_zip=0
    local is_a_zip=0

    [[   $1 = adb ]] && obtain_minecraft_apks && minecraft_apk_files=~/tmp/minecraft_split_apk
    [[ ! $1 = adb ]] && minecraft_apk_files=$1

    [[ ! -d "$minecraft_apk_files"      ]]  && is_not_a_dir=1
    [[ ! "$minecraft_apk_files" = *.zip ]]  && is_not_a_zip=1
    [[   "$minecraft_apk_files" = *.zip ]]  && is_a_zip=1

    if [[ $is_a_zip -eq 1 && ! -f "$minecraft_apk_files" ]]; then
        echo "$minecraft_apk_files not found"
        input_error=1
    fi

    if [[ $is_not_a_dir -eq 1 && $is_not_a_zip -eq 1 ]]; then
        input_error=1
    fi

    if [[ $input_error -eq 1 ]]; then
        echo -e "\e[1;91mERROR: \e[0mValid input not provided"
        exit
    fi
}

function minecraft_apk_paths {
    for path in $(adb shell pm path com.mojang.minecraftpe | sed 's/package://' ); do
        echo "$path"
    done
}

function obtain_minecraft_apks {
    mkdir -p ~/tmp/minecraft_split_apk

    for file in $(minecraft_apk_paths); do
        adb pull $file ~/tmp/minecraft_split_apk/
    done
}

function generate_apk_key  {
    [ -f $apk_key_path ] && echo "debug.keystore already exists, skipping" && return 1
    keytool -genkey \
    -noprompt \
    -v \
    -keystore $apk_key_path \
    -storepass $keystore \
    -keypass $keypass \
    -alias signkey \
    -keyalg RSA \
    -keysize 2048 \
    -validity 20000 \
    -dname "CN=, OU=, O=, L=, S=, C="
}

function move_output {
mv $signed_apk_path $output_apk_path &&\
printf "\n""\e[1m""The output file is in the following directory: ""\e[0m""$output_apk_path""\n"
}

function sign_apk {
    printf "\e[1m""Downloading uber_apk_signer""\e[0m""\e[90m""\n"
    wget -q --show-progress -O ~/tmp/uber_apk_signer.jar $link_uber_apk_signer
    printf "\e[0m"

    [ ! -f $apk_key_path ]    && echo -e "\e[1;91m""ERROR: ""\e[0m""debug.keystore does not exist, exiting" && exit
    [ ! -f $modded_apk_path ] && echo -e "\e[1;91m""ERROR: ""\e[0m""APK file not found" && exit

    java -jar ~/tmp/uber_apk_signer.jar -a $1 --ks $apk_key_path --ksAlias signkey --ksPass $keystore --ksKeyPass $keypass

    signed_apk_path=$( echo $modded_apk_path | sed 's/.apk/-aligned-signed.apk/' )
}

function sign_apk_on_termux {
    [ ! -f $apk_key_path ]    && echo -e "\e[1;91m""ERROR: ""\e[0m""debug.keystore does not exist, exiting" && exit
    [ ! -f $modded_apk_path ] && echo -e "\e[1;91m""ERROR: ""\e[0m""APK file not found" && exit

    apksigner sign --ks ~/tmp/debug.keystore --ks-key-alias signkey --ks-pass pass:$keystore --key-pass pass:$keypass $1
    signed_apk_path=$1
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

function nether_roof_x86_64 {
    local old_hex="004C8D4C2408B900008000"
    local new_hex="004C8D4C2408B900000001"

    local old_hex_formatted=$(echo -n "$old_hex" | sed 's/../\\x&/g')
    local new_hex_formatted=$(echo -n "$new_hex" | sed 's/../\\x&/g')

    sed -i "s/$old_hex_formatted/$new_hex_formatted/g" ~/tmp/decompiled_minecraft/root/lib/x86_64/libminecraftpe.so
}

function nether_roof_patch {
    local sucess_test="0"
    local sucess_test_arm32="0"
    local sucess_test_arm64="0"
    local sucess_test_x86_64="0"

    [ -d ~/tmp/decompiled_minecraft/root/lib/arm64-v8a   ]   &&  nether_roof_arm64   &&   sucess_test="1"  sucess_test_arm64="1"
    [ -d ~/tmp/decompiled_minecraft/root/lib/armeabi-v7a ]   &&  nether_roof_arm32   &&   sucess_test="1"  sucess_test_arm32="1"
    [ -d ~/tmp/decompiled_minecraft/root/lib/x86_64      ]   &&  nether_roof_x86_64  &&   sucess_test="1"  sucess_test_x86_64="1"
    [ $sucess_test -eq 1 ] && echo -e "\e[36m""Nether_roof_patch:""\e[0m""Patch applied"
    [ $sucess_test_arm32  -eq 1 ]   &&   echo -e "                 \e[0m"" ↳ (ARM_32)"
    [ $sucess_test_arm64  -eq 1 ]   &&   echo -e "                 \e[0m"" ↳ (ARM_64)"
    [ $sucess_test_x86_64 -eq 1 ]   &&   echo -e "                 \e[0m"" ↳ (X86_64)"
    [ $sucess_test -eq 0 ] && echo -e "\e[36m""Nether_roof_patch:""\e[0m""\e[31m""Error - Patch not applied""\e[0m"
}

function materialbinloader_arm64 {
    cd ~/tmp/decompiled_minecraft/root/lib/arm64-v8a/
    wget -q --show-progress -O libmaterialbinloader-arm64.so $link_materialbinloader_arm64_so_file
    patchelf --add-needed libmaterialbinloader-arm64.so libminecraftpe.so
    cd ~/
}

function materialbinloader_arm32 {
    cd ~/tmp/decompiled_minecraft/root/lib/armeabi-v7a/
    wget -q --show-progress -O libmaterialbinloader-arm32.so $link_materialbinloader_arm32_so_file
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

    [ $sucess_test -eq 1 ]  && echo -e "\e[36m""Materialbinloader_patch:""\e[0m""Patch applied"
    [ $sucess_test_arm32 -eq 1 ]   &&  echo -e "                        ""\e[0m""↳ (ARM_32)"
    [ $sucess_test_arm64 -eq 1 ]   &&  echo -e "                        ""\e[0m""↳ (ARM_64)"
    [ $sucess_test -eq 0 ]  && echo -e "\e[36m""Materialbinloader_patch:""\e[0m""\e[31m""Error - Patch not applied""\e[0m"
}

function aply_patches {
    cd ~/
    [ $nether_roof_limit_to_256 -eq 1 ]  &&   nether_roof_patch
    [ $materialbinloader -eq 1 ]         &&   materialbinloader_patch
}

function minecraft_installation_adb {
    adb shell mv /sdcard/Android/data/com.mojang.minecraftpe /sdcard/Android/data/com.mojang.minecraftpe.backup
    adb shell pm uninstall com.mojang.minecraftpe
    adb install $output_apk_path
    adb shell mv /sdcard/Android/data/com.mojang.minecraftpe.backup /sdcard/Android/data/com.mojang.minecraftpe
}

function clear_tmp {
   #rm -f  ~/tmp/debug.keystore
    rm -f  ~/tmp/APKEditor.jar
    rm -f  ~/tmp/uber_apk_signer.jar
    rm -f  ~/tmp/Minecraft-merged.apk
    rm -f  ~/tmp/minecraft_modded.apk
   #rm -f  ~/tmp/minecraft_modded-aligned-signed.apk
    rm -f  ~/tmp/minecraft_modded-aligned-signed.apk.idsig
    rm -rf ~/tmp/decompiled_minecraft
    rm -rf ~/tmp/minecraft_split_apk
}

check_dependences

check_input_files $1

printf "\e[1m""Downloading APKEditor""\e[0m""\e[90m""\n"
wget -q --show-progress -O ~/tmp/APKEditor.jar $link_apkeditor
printf "\e[0m"

generate_apk_key

java -jar ~/tmp/APKEditor.jar m -i $minecraft_apk_files -o ~/tmp/Minecraft-merged.apk &&\
mkdir  -p ~/tmp/decompiled_minecraft
java -jar ~/tmp/APKEditor.jar d -i ~/tmp/Minecraft-merged.apk -o ~/tmp/decompiled_minecraft && aply_patches

modded_apk_path=~/tmp/minecraft_modded.apk
signed_apk_path=~/tmp/minecraft_modded_signed.apk
output_apk_path=$output_apk_folder/$output_apk_name

java -jar ~/tmp/APKEditor.jar b -i ~/tmp/decompiled_minecraft -o $modded_apk_path
[[ ! $(uname -o) = Android ]] && sign_apk $modded_apk_path && move_output
[[   $(uname -o) = Android ]] && sign_apk_on_termux $modded_apk_path && move_output

#it is to uninstall the original game and install the modded apk using adb
[[ $1 = adb ]] && [[ -f $output_apk_path ]] && minecraft_installation_adb
[[ ! -f $output_apk_path ]] && [[ ! $(uname -o) = Android ]] && echo "Error: $output_apk_path do not exist or is not a file"

clear_tmp
