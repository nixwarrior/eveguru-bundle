#!/usr/bin/env nu

use std/log
use std/xml xaccess

$env.NU_LOG_LEVEL = "debug"
$env.WINEPREFIX = $env.HOME + "/.wine-eveguru"

const BUNDLE_DIR = path self | path dirname --num-levels 3
const RESOURCES_DIR = $BUNDLE_DIR + "/Contents/Resources"
const EVEGURU_EXE = $RESOURCES_DIR + "/EveGuru.exe"

let PROGRAM_DATA_DIR = $env.WINEPREFIX + "/drive_c/ProgramData/EveGuru"
let PROGRAM_DATA_CONFIG = $PROGRAM_DATA_DIR + "/EveGuru.config"
let EVEGURU_VERSION = $PROGRAM_DATA_DIR + "/version.json"

let DATA_DIR = get_data_directory | default ($BUNDLE_DIR + "/Contents/Data")
let EVEGURU_CONFIG = $DATA_DIR + "/EveGuru.config"

const RELEASE_URL = "https://app.eveguru.online/app/api/updateinfo"
const RELEASE_CHANNEL = {stable: "latestStable", preview: "latestTest"}

def get_data_directory [] {
  if not ($PROGRAM_DATA_CONFIG | path exists) {
    return null
  }

  open $PROGRAM_DATA_CONFIG
    | from xml
    | xaccess [configuration appSettings add]
    | where attributes.key == "dataDirectory"
    | get attributes.value.0
    | str replace "Z:" ""
    | str replace --all "\\" "/"
}

def is_installed [] {
  $EVEGURU_EXE | path exists
}

def get_release_channel [] {
  if not ($EVEGURU_CONFIG | path exists) {
    return null
  }

  open $EVEGURU_CONFIG
    | from xml
    | xaccess [configuration appUpdateSettings settings option]
    | where attributes.name == "enablePreviewUpdates"
    | get --optional attributes.check.0
    | if ($in == "true") { $RELEASE_CHANNEL.preview } else { null }
}

def install [release_channel: string] {
  let release = http get $RELEASE_URL | get $release_channel
  let url = $release.app.downloadUrl
  let version = $release.app.version
  let file = mktemp --tmpdir

  log debug $"Downloading ($url)"
  http get $url | save --force --progress $file

  log debug "Installing to $RESOURCES_DIR"
  ^unzip -o $file -d $RESOURCES_DIR

  rm $file

  log debug $"Installed version ($version)"
  {version: $version} | save --force $EVEGURU_VERSION
}

def main [] {
  log debug $"BUNDLE_DIR=($BUNDLE_DIR)"
  log debug $"RESOURCES_DIR=($RESOURCES_DIR)"
  log debug $"EVEGURU_EXE=($EVEGURU_EXE)"
  log debug $"EVEGURU_VERSION=($EVEGURU_VERSION)"
  log debug $"RELEASE_URL=($RELEASE_URL)"
  log debug $"RELEASE_CHANNEL=($RELEASE_CHANNEL)"
  log debug $"DATA_DIR=($DATA_DIR)"
  log debug $"EVEGURU_CONFIG=($EVEGURU_CONFIG)"

  log debug "Checking if the application is installed"
  if (is_installed) {
    log debug "The application is installed because file $EVEGURU_EXE is found"
    log debug "Checking for updates"
    let release_channel = get_release_channel | default $RELEASE_CHANNEL.stable
    let release = http get $RELEASE_URL | get $release_channel
    let old_version = open $EVEGURU_VERSION | get version
    let new_version = $release.app.version
    if ($new_version > $old_version) {
      log debug "A new version is available"
      install $release_channel
    }
  } else {
    log debug "The application is not installed because file $EVEGURU_EXE is not found"
    log debug "Installing the latest stable version of the application"
    install $RELEASE_CHANNEL.stable
  }

  log debug "Launching the application"
  exec wine $EVEGURU_EXE -linux -macCrossover
}
