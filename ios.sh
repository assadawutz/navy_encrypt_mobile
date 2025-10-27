# DIR: <project-root>   # WHY: one-stop ops + notify + ff2s theme + safety
#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_NAME="ff2s"
COLS(){ tput cols 2>/dev/null || echo 80; }
BOLD=$'\033[1m'; RST=$'\033[0m'; BLACK=$'\033[30m'; GRAY=$'\033[90m'; WHITE=$'\033[97m'; PINK=$'\033[95m'
ICON_OK="✅"; ICON_WARN="⚠️ "; ICON_ERR="❌"; ICON_INFO="ℹ️ "; ICON_ROCKET="🚀"; ICON_WRENCH="🛠️"; ICON_BOX="📦"
ui_rule(){ local ch="${1:-─}"; printf "${GRAY}%*s${RST}\n" "$(COLS)" '' | tr ' ' "$ch"; }
ui_center(){ local s="$*"; local w=$(COLS); local pad=$(( (w - ${#s}) / 2 )); ((pad<0)) && pad=0; printf '%*s%s\n' "$pad" '' "$s"; }
ui_box(){ local title="$1"; shift||true; echo "╔════════════════════════════════════════════════════════════════╗"; printf "║ %s\n" "$title"; while [[ $# -gt 0 ]]; do printf "║ %s\n" "$1"; shift; done; echo "╚════════════════════════════════════════════════════════════════╝"; }
ok(){   printf "${PINK}${ICON_OK}${RST} ${WHITE}%s${RST}\n"   "$*"; }
warn(){ printf "${GRAY}${ICON_WARN}${RST} ${WHITE}%s${RST}\n" "$*"; }
err(){  printf "${BLACK}${ICON_ERR}${RST} ${WHITE}%s${RST}\n" "$*"; }
info(){ printf "${GRAY}${ICON_INFO}${RST} ${WHITE}%s${RST}\n" "$*"; }
notify(){ local t="${1:-$PROJECT_NAME}" m="${2:-}" s="${3:-}"; if command -v terminal-notifier >/dev/null 2>&1; then terminal-notifier -title "$t" -message "$m" ${s:+-subtitle "$s"} >/dev/null 2>&1 || true; else osascript -e "display notification \"${m//\"/\\\"}\" with title \"${t//\"/\\\"}\"${s:+ subtitle \"${s//\"/\\\"}\"}" || true; fi; }
CURRENT_TASK=""; set_task(){ CURRENT_TASK="$1"; }; trap 'C=$?; [[ $C -ne 0 ]] && err "ล้มเหลว($C)" && notify "$PROJECT_NAME" "ล้มเหลว ($CURRENT_TASK)" "code $C"' EXIT
TEAM_ID_DEFAULT="UP4CVNXUM9"
DEFAULT_SIM_CANDIDATES=("iPhone 16 Pro" "iPhone 16" "iPhone 15" "iPhone 14")
BAN_PODS=("Fabric" "Crashlytics" "Firebase/CoreOnly" "BoringSSL-GRPC")
PATH_UPDATE="$HOME/.pub-cache/bin:$HOME/fvm/default/bin:/usr/local/bin:/opt/homebrew/bin"
die(){ err "$*"; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1; }
pth(){ export PATH="$PATH_UPDATE:$PATH"; }
root(){ [[ -f "pubspec.yaml" ]] || die "ต้องรันที่ root โปรเจ็กต์"; [[ -d ios ]] || die "ไม่พบ ios/"; }
confirm(){ read -r -p "${ICON_WARN} พิมพ์ ${BOLD}CONFIRM${RST} เพื่อยืนยัน: " a; [[ "$a" = "CONFIRM" ]] || die "ยกเลิกโดยผู้ใช้"; }

ensure_base(){ pth; need brew || die "ต้องมี Homebrew"; need jq || { brew install jq; }; need fvm || { brew tap leoafarias/fvm >/dev/null && brew install fvm; }; xcode-select -p >/dev/null 2>&1 || sudo xcode-select --switch /Applications/Xcode.app; xcodebuild -version >/dev/null 2>&1 || sudo xcodebuild -runFirstLaunch || true; need pod || { brew install cocoapods; }; ok "พร้อมใช้งาน"; }
use_fvm(){ if [[ -f ".fvm/fvm_config.json" ]]; then v="$(/usr/bin/env jq -r '.flutter' .fvm/fvm_config.json)"; fvm use "3.3.8" --force; else fvm install 3.3.8 || true; fvm use 3.3.8 --force; fi; fvm flutter --version >/dev/null; }
write_podfile(){ cat > ios/Podfile <<'RUBY'
platform :ios, '13.0'
ENV['COCOAPODS_DISABLE_STATS'] = 'true'
project 'Runner', { 'Debug' => :debug, 'Profile' => :release, 'Release' => :release }
def flutter_root
  g = File.expand_path(File.join('..','Flutter','Generated.xcconfig'), __FILE__)
  raise "#{g} must exist. Run 'flutter pub get' first." unless File.exist?(g)
  File.foreach(g){|l| m=l.match(/FLUTTER_ROOT\=(.*)/); return m[1].strip if m }
  raise "FLUTTER_ROOT not found in #{g}."
end
require File.expand_path(File.join(flutter_root,'packages','flutter_tools','bin','podhelper.rb'))
flutter_ios_podfile_setup if defined?(flutter_ios_podfile_setup)
install! 'cocoapods', :deterministic_uuids => false, :warn_for_multiple_pod_sources => false
target 'Runner' do
  if ENV['USE_DYNAMIC_FRAMEWORKS'] == '1' then use_frameworks! :linkage => :dynamic else use_frameworks! :linkage => :static end
  use_modular_headers!
  if defined?(flutter_install_all_ios_pods)
    flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  elsif defined?(install_all_flutter_pods)
    install_all_flutter_pods File.dirname(File.realpath(__FILE__))
  else
    raise 'No flutter pods installer method found.'
  end
end
post_install do |installer|
  TEAM_ID = 'UP4CVNXUM9'; intel = `uname -m`.strip == 'x86_64'
  installer.pods_project.targets.each do |t|
    flutter_additional_ios_build_settings(t) if defined?(flutter_additional_ios_build_settings)
    t.build_configurations.each do |cfg|
      cfg.build_settings['ENABLE_BITCODE'] = 'NO'
      cfg.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
      cfg.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'YES'
      cfg.build_settings['SWIFT_VERSION'] ||= '5.0'
      cfg.build_settings['DEFINES_MODULE'] = 'YES'
      cfg.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
      cfg.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      if intel
        cfg.build_settings['ARCHS[sdk=iphonesimulator*]'] = 'x86_64'
        cfg.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
      end
      flags = cfg.build_settings['OTHER_LDFLAGS']; cfg.build_settings['OTHER_LDFLAGS'] = flags.uniq if flags.is_a?(Array)
      cfg.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
      cfg.build_settings['DEVELOPMENT_TEAM'] = TEAM_ID if (cfg.build_settings['DEVELOPMENT_TEAM'].to_s.strip.empty?)
    end
  end
  installer.aggregate_targets.map(&:user_project).uniq.each do |proj|
    proj.targets.each do |t|
      next unless t.name == 'Runner'
      t.build_configurations.each do |cfg|
        cfg.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
        cfg.build_settings['ONLY_ACTIVE_ARCH'] = 'NO'
        cfg.build_settings.delete('EXCLUDED_ARCHS')
        cfg.build_settings.delete('EXCLUDED_ARCHS[sdk=iphoneos*]')
        if intel
          cfg.build_settings['ARCHS[sdk=iphonesimulator*]'] = 'x86_64'
          cfg.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
        end
        cfg.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
        cfg.build_settings['DEVELOPMENT_TEAM'] = TEAM_ID if (cfg.build_settings['DEVELOPMENT_TEAM'].to_s.strip.empty?)
      end
    end
    proj.save
  end
end
RUBY
}
sanitize_project(){ grep -rl "Fabric/run" ios/Runner.xcodeproj 2>/dev/null | xargs sed -i '' '/Fabric\/run/d' || true; for p in "${BAN_PODS[@]}"; do sed -i '' "/pod ['\"]${p//\//\\/}['\"][^\)]*$/d" ios/Podfile || true; done; LC_ALL=C sed -i '' "s/’/'/g; s/‘/'/g; s/“/\"/g; s/”/\"/g" ios/Podfile || true; }
pods_clean_install(){ pushd ios >/dev/null; echo "จะลบ Pods/Lock/Symlinks ทั้งหมด"; read -r -p "CONFIRM เพื่อทำต่อ: " a; [[ "$a" = "CONFIRM" ]] || exit 1; rm -rf Pods Podfile.lock .symlinks Flutter/Flutter.framework Flutter/Flutter.podspec; pod deintegrate || true; pod install || { pod repo update; pod install --repo-update; }; popd >/dev/null; }
add_dummy_swift(){ [[ -f ios/Runner/Dummy.swift ]] || echo "// keep Swift runtime" > ios/Runner/Dummy.swift; }
nuke_derived(){ echo "ล้าง DerivedData/Runner-*"; read -r -p "CONFIRM เพื่อทำต่อ: " a; [[ "$a" = "CONFIRM" ]] || exit 1; rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-* || true; }
set_team(){ local TEAM="${1:-$TEAM_ID_DEFAULT}"; local PBX="ios/Runner.xcodeproj/project.pbxproj"; [[ -f "$PBX" ]] || die "ไม่พบ $PBX"; sed -i '' "s/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/g" "$PBX" || true; if grep -q "DEVELOPMENT_TEAM" "$PBX"; then sed -i '' "s/DEVELOPMENT_TEAM = [A-Z0-9]\{5,12\};/DEVELOPMENT_TEAM = $TEAM;/g" "$PBX"; else sed -i '' "s/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Automatic;\n\t\t\tDEVELOPMENT_TEAM = $TEAM;/g" "$PBX"; fi; }
pick_simulator(){ local id=""; for n in "${DEFAULT_SIM_CANDIDATES[@]}"; do id=$(xcrun simctl list devices available | awk -v n="$n" -F'[()]' '$0 ~ n && /Shutdown|Booted/ {print $2; exit}'); [[ -n "$id" ]] && break; done; [[ -n "$id" ]] || id=$(xcrun simctl list devices available | awk -F'[()]' '/Shutdown|Booted/ {print $2; exit}'); echo "$id"; }
fix_bom_version(){ local f="android/app/build.gradle"; [[ -f "$f" ]] || return 0; if grep -q 'com.google.firebase:firebase-bom:' "$f" && ! grep -q 'firebase-bom:[0-9]' "$f"; then sed -i '' 's/com.google.firebase:firebase-bom:/com.google.firebase:firebase-bom:34.4.0/' "$f"; fi; }
fix_kotlin_version(){ local f="android/build.gradle"; [[ -f "$f" ]] || return 0; if grep -q "ext.kotlin_version" "$f"; then sed -i '' "s/ext.kotlin_version *= *['\"][0-9.]\+['\"]/ext.kotlin_version = '1.8.22'/" "$f"; fi; }
gradle_clean_build(){ pushd android >/dev/null; ./gradlew --no-daemon --stacktrace clean || true; popd >/dev/null; fvm flutter build apk || flutter build apk || true; }
fix_dexing_artifacts(){ rm -rf "$HOME/.gradle/caches/transforms-3" "$HOME/.gradle/caches/modules-2/files-2.1" || true; gradle_clean_build; }
git_use_ssh(){ local url; url="$(git remote get-url origin 2>/dev/null || true)"; [[ -z "$url" ]] && return 0; if [[ "$url" =~ ^https://github.com/ ]]; then local p="${url#https://github.com/}"; p="${p%.git}"; git remote set-url origin "git@github.com:${p}.git"; fi; }
enable_lfs_defaults(){ git lfs install || true; git lfs track "*.ipa" "*.xcarchive" "*.apk" "*.aab" "*.png" "*.jpg" "*.zip" "*.mp4" "*.bin" || true; git add .gitattributes || true; }
fix_flutter_cache(){ fvm flutter pub get || true; fvm flutter pub cache repair || true; fvm flutter precache --ios --android || true; fvm flutter clean || true; }
fix_ruby_getcwd(){ brew reinstall cocoapods || brew install cocoapods; sudo xcode-select --switch /Applications/Xcode.app || true; }
doctor(){ need brew && need fvm && need pod && need jq; git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git remote -v | head -n1 || true; }
cmd_init(){ root; ensure_base; use_fvm; fvm flutter clean; fvm flutter pub get; fvm flutter precache --ios; [[ -f ios/Podfile ]] || write_podfile; sanitize_project; add_dummy_swift; pods_clean_install; }
cmd_pods(){ root; ensure_base; sanitize_project; add_dummy_swift; pods_clean_install; }
cmd_run_sim(){ root; ensure_base; use_fvm; open -a Simulator || true; id="$(pick_simulator)"; [[ -n "$id" ]] || die "ไม่พบ Simulator"; xcrun simctl bootstatus "$id" || xcrun simctl boot "$id" || true; fvm flutter run -d "$id"; }
cmd_run_device(){ root; ensure_base; use_fvm; id="$(fvm flutter devices --machine | jq -r '.[] | select(.platform==\"ios\") | .id' | head -n1)"; [[ -n "$id" ]] || die "ไม่พบ iOS device"; fvm flutter run -d "$id"; }
cmd_build_debug(){ root; ensure_base; use_fvm; nuke_derived; fvm flutter build ios --debug; }
cmd_build_release(){ root; ensure_base; use_fvm; nuke_derived; fvm flutter build ios --release; }
cmd_archive(){ root; ensure_base; use_fvm; nuke_derived; xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates DEVELOPMENT_TEAM="${1:-$TEAM_ID_DEFAULT}" CODE_SIGN_STYLE=Automatic archive -archivePath build/Runner.xcarchive; }
cmd_set_team(){ set_team "${1:-$TEAM_ID_DEFAULT}"; }
cmd_ns_use_dart219(){ fvm install 3.7.12 || true; fvm use 3.7.12 --force; fvm dart --version; }
cmd_ns_check(){ root; use_fvm; fvm dart pub outdated --mode=null-safety || true; fvm dart analyze || true; }
cmd_ns_migrate(){ root; use_fvm; echo "จะ backup commit ก่อน migrate"; read -r -p "CONFIRM เพื่อทำต่อ: " a; [[ "$a" = "CONFIRM" ]] || exit 1; git add . && git commit -m "chore: pre-migrate backup" || true; fvm dart pub upgrade --major-versions; fvm dart migrate --apply-changes; fvm dart fix --apply; fvm dart analyze || true; }
cmd_ns_run_legacy(){ root; use_fvm; fvm flutter run --no-sound-null-safety; }
fix_pods_fast(){ (cd ios && pod install) || true; }
fix_pods_repo(){ (cd ios && echo "repo update ต้อง CONFIRM"; read -r -p "CONFIRM เพื่อทำต่อ: " a; [[ "$a" = "CONFIRM" ]] && pod repo update && pod install --repo-update) || true; }
fix_ruby_getcwd_main(){ fix_ruby_getcwd; }
fix_sim(){ open -a Simulator || true; id="$(pick_simulator)"; if [[ -n "$id" ]]; then xcrun simctl shutdown "$id" || true; xcrun simctl erase "$id" || true; xcrun simctl boot "$id" || true; else echo "ไม่พบ Simulator จะ erase all?"; read -r -p "CONFIRM เพื่อทำต่อ: " a; [[ "$a" = "CONFIRM" ]] && xcrun simctl erase all || true; fi; }
fix_flutter_cache_main(){ fix_flutter_cache; }
fix_git_ssh(){ git_use_ssh; }
fix_lfs_main(){ enable_lfs_defaults; }
fix_bom(){ fix_bom_version; }
fix_kotlin(){ fix_kotlin_version; }
fix_gradle_clean(){ gradle_clean_build; }
fix_dexing(){ fix_dexing_artifacts; }
case "${1:-}" in
  help|-h|--help|h)  echo "ใช้: init|pods|run-sim|run-device|build-debug|build-release|archive|set-team|ns-use-dart219|ns-check|ns-migrate|ns-run-legacy|fix-*|doctor";;
  doctor|d)          doctor;;
  init|i)            cmd_init;;
  pods|p)            cmd_pods;;
  run-sim|rs)        cmd_run_sim;;
  run-device|rd)     cmd_run_device;;
  build-debug|bd)    cmd_build_debug;;
  build-release|br)  cmd_build_release;;
  archive|ar)        shift || true; cmd_archive "${1:-$TEAM_ID_DEFAULT}";;
  set-team|st)       shift || true; cmd_set_team "${1:-$TEAM_ID_DEFAULT}";;
  ns-use-dart219|nsu)  cmd_ns_use_dart219;;
  ns-check|nsc)        cmd_ns_check;;
  ns-migrate|nsm)      cmd_ns_migrate;;
  ns-run-legacy|nsr)   cmd_ns_run_legacy;;
  fix-pods-fast|fpf)     fix_pods_fast;;
  fix-pods-repo|fpr)     fix_pods_repo;;
  fix-ruby-getcwd|frg)   fix_ruby_getcwd_main;;
  fix-derived|fd)        nuke_derived;;
  fix-sim|fs)            fix_sim;;
  fix-flutter-cache|ffc) fix_flutter_cache_main;;
  fix-git-ssh|fgs)       fix_git_ssh;;
  fix-lfs|flfs)          fix_lfs_main;;
  fix-bom|fbom)          fix_bom;;
  fix-kotlin|fkt)        fix_kotlin;;
  fix-gradle-clean|fgc)  fix_gradle_clean;;
  fix-dexing|fdx)        fix_dexing;;
  *) echo "ff2s help เพื่อดูคำสั่ง"; exit 1;;
esac
