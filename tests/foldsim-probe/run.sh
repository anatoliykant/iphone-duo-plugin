#!/bin/bash
# Checks foldsim against the probe app on throwaway simulators, one at a time:
#   tests/foldsim-probe/run.sh [duo] [duo271] [iphone] [ipad]        (default: all four)
# Each device gets its own simulator (foldsim-verify-*), booted alone and deleted at the end; other
# simulators on the Mac are never touched. Needs Xcode 27.2 RC or later (DEVELOPER_DIR) with the
# iOS 27.2 runtimes; duo271 needs the iOS 27.1 runtime. If duoctl is on PATH, the Duo runs compare
# with it. Prints PASS / FAIL / SKIP per check and exits 1 when a check failed.
set -u
here=$(cd "$(dirname "$0")" && pwd)
foldsim=$here/../../skills/foldsim/scripts/foldsim
work=${FOLDSIM_VERIFY_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/foldsim-verify.XXXXXX")}
mkdir -p "$work"
app=$("$here/build.sh" "$work") || { echo "the probe app did not build"; exit 1; }
bundle=dev.foldsim.probe
failed=0 udid= tag= console= mark=0

pass() { echo "PASS $*"; }
fail() { echo "FAIL $*"; failed=$((failed + 1)); }
near() { awk -v a="$1" -v b="$2" -v t="$3" 'BEGIN { d = a - b; exit !(d <= t && -d <= t) }'; }
fs() { "$foldsim" -d "$udid" "$@"; }
field() { python3 -I -c 'import json, sys; d = json.load(sys.stdin); print(eval(sys.argv[1], {"d": d}))' "$1" 2>/dev/null; }
active() { fs --json state 2>/dev/null | field '[x for x in d["displays"] if x["active"]][0]["'"$1"'"]'; }

# --- the probe app -------------------------------------------------------------------------------
launch() {
    stop
    : > "$work/$tag-probe.log"
    env SIMCTL_CHILD_PROBE_MASK="$1" xcrun simctl launch --console-pty "$udid" "$bundle" >> "$work/$tag-probe.log" 2>&1 &
    console=$!
    for _ in $(seq 1 40); do grep -q '"event":"window"' "$work/$tag-probe.log" && break; sleep 0.5; done
    sleep 1
}
stop() {
    [ -n "$console" ] || return 0
    xcrun simctl terminate "$udid" "$bundle" >/dev/null 2>&1
    kill "$console" 2>/dev/null
    console=
    sleep 1
}
remember() { mark=$(wc -l < "$work/$tag-probe.log" | tr -d ' '); }
window() { python3 -I "$here/probe_log.py" window "$work/$tag-probe.log"; }
touches() { python3 -I "$here/probe_log.py" touches "$work/$tag-probe.log" "$mark"; }

# --- checks --------------------------------------------------------------------------------------
expect_exit() { # <name> <expected exit code> <foldsim arguments…>
    local name=$1 want=$2; shift 2
    fs "$@" >"$work/last.out" 2>&1
    local got=$?
    if [ "$got" = "$want" ]; then pass "$name"; else fail "$name (exit $got, wanted $want: $(tail -n 2 "$work/last.out" | tr '\n' ' '))"; fi
    [ "$got" = "$want" ]
}
rotate_check() { # <orientation> [expected exit]
    local want=${2:-0}
    expect_exit "$tag rotate $1 → exit $want" "$want" rotate "$1" || return
    [ "$want" = 0 ] || return 0
    sleep 1
    local seen; seen=$(window | cut -d' ' -f3)
    if [ "$seen" = "$1" ]; then pass "$tag app sees $1"; else fail "$tag app sees ${seen:-nothing}, not $1"; fi
}
touch_check() { # <x> <y>: the app must get a tap there, within 2 pt
    remember
    expect_exit "$tag tap $1 $2" 0 tap "$1" "$2" || return
    sleep 0.8
    local began; began=$(touches | awk '$1 == "began" { print $2, $3; exit }')
    if [ -n "$began" ] && near "${began% *}" "$1" 2 && near "${began#* }" "$2" 2; then
        pass "$tag app got the tap at $began"
    else
        fail "$tag tap ($1, $2) arrived at '${began:-nowhere}'"
    fi
}
nothing_check() { # <x> <y>: foldsim sends the tap, and the app must get nothing
    remember
    fs tap "$1" "$2" >/dev/null 2>&1
    sleep 0.8
    if [ -z "$(touches)" ]; then pass "$tag a tap at ($1, $2) reaches nothing"; else fail "$tag a tap at ($1, $2) arrived: $(touches | head -n 1)"; fi
}
corners() { # taps at a quarter and three quarters of the active display and at its centre: clear of the
            # status bar, the rounded corners, the home indicator and the fold, so any mapping error shows
    local size w h; size=$(active points)   # e.g. [951.0, 669.0]
    w=$(echo "$size" | tr -d '[] ' | cut -d, -f1); h=$(echo "$size" | tr -d '[] ' | cut -d, -f2)
    touch_check "$(awk -v w="$w" 'BEGIN { print w / 4 }')" "$(awk -v h="$h" 'BEGIN { print h / 4 }')"
    touch_check "$(awk -v w="$w" 'BEGIN { print w * 3 / 4 }')" "$(awk -v h="$h" 'BEGIN { print h * 3 / 4 }')"
    touch_check "$(awk -v w="$w" 'BEGIN { print w / 2 }')" "$(awk -v h="$h" 'BEGIN { print h / 2 }')"
}
pose_check() { # <pose> <role> <orientation> [hinge angle]
    expect_exit "$tag pose $1" 0 pose "$1" || return
    local role orientation angle
    role=$(active role); orientation=$(active orientation)
    angle=$(fs --json state 2>/dev/null | field 'd.get("hingeAngle")')
    if [ "$role $orientation" = "$2 $3" ]; then pass "$tag $1 shows on the $2 display, $3"; else fail "$tag $1 shows on '$role' '$orientation'"; fi
    if [ -n "${4:-}" ]; then
        if near "$angle" "$4" 6; then pass "$tag $1 hinge ${angle}°"; else fail "$tag $1 hinge ${angle}°, wanted ${4}°"; fi
    fi
    sleep 1
    local seen; seen=$(window | cut -d' ' -f3)
    if [ "$seen" = "$3" ]; then pass "$tag $1: the app sees $3"; else fail "$tag $1: the app sees ${seen:-nothing}"; fi
}
oracle() { # duoctl reads what foldsim did
    command -v duoctl >/dev/null || { echo "SKIP $tag duoctl comparison: duoctl is not on PATH"; return; }
    local ours theirs
    ours=$(fs --json state 2>/dev/null | field '"%s %s %s" % ([x for x in d["displays"] if x["active"]][0]["role"], round(d["hingeAngle"]), [round(v) for v in [x for x in d["displays"] if x["active"]][0]["points"]])')
    theirs=$(duoctl -d "$udid" state 2>/dev/null | field '"%s %s %s" % (d["activeScreen"], round(d["hingeAngle"]), [round(v) for v in d["sizePoints"]])')
    if [ -n "$ours" ] && [ "$ours" = "$theirs" ]; then pass "$tag duoctl agrees: $ours"; else fail "$tag foldsim '$ours' vs duoctl '$theirs'"; fi
}
png_size() { sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null | awk '/pixel/ { printf "%s ", $2 }'; }

# --- devices -------------------------------------------------------------------------------------
wait_for_quiet() { # up to 20 minutes while the Mac is busier than FOLDSIM_VERIFY_MAX_LOAD (default: cores)
    local limit=${FOLDSIM_VERIFY_MAX_LOAD:-$(sysctl -n hw.ncpu)} load
    for _ in $(seq 1 40); do
        load=$(sysctl -n vm.loadavg | awk '{ print int($2) }')
        [ "$load" -lt "$limit" ] && ! pgrep -f 'xcodebuild (build|test)' >/dev/null && return
        echo "     waiting: load average $load, limit $limit"
        sleep 30
    done
}
boot() { # <tag> <device type> <runtime>
    tag=$1
    wait_for_quiet
    if ! udid=$(xcrun simctl create "foldsim-verify-$1" "$2" "$3" 2>/dev/null); then
        echo "SKIP $1: cannot create $2 with $3"
        udid=
        return 1
    fi
    xcrun simctl boot "$udid" && xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1
    sleep 10   # let SpringBoard settle before the first rotation or screenshot
    xcrun simctl install "$udid" "$app"
}
teardown() {
    stop
    xcrun simctl shutdown "$udid" >/dev/null 2>&1
    xcrun simctl delete "$udid" && echo "deleted foldsim-verify-$tag"
    udid=
}

duo() { # <tag> <runtime>
    boot "$1" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo "$2" || return
    expect_exit "$tag doctor" 0 doctor
    [ "$(active role)" = cover ] && pass "$tag boots on the cover" || fail "$tag does not boot on the cover"
    launch all
    expect_exit "$tag hinge open" 0 hinge open && oracle
    [ "$(active role)" = inner ] && pass "$tag open shows the inner display" || fail "$tag open: $(active role)"
    expect_exit "$tag hinge 30 in one move from open" 0 hinge 30
    sleep 2
    [ "$(active role)" = cover ] && pass "$tag one move from open to 30° shows the cover" || fail "$tag one move to 30°: $(active role)"
    expect_exit "$tag hinge closed" 0 hinge closed && oracle
    if command -v duoctl >/dev/null; then
        duoctl -d "$udid" open >/dev/null 2>&1
        [ "$(active role)" = inner ] && pass "$tag foldsim reads duoctl's open" || fail "$tag foldsim misreads duoctl's open"
        duoctl -d "$udid" close >/dev/null 2>&1
    fi
    if [ "$tag" = duo271 ]; then
        for cycle in 1 2 3 4 5 6 7 8 9 10; do
            fs hinge open >/dev/null 2>&1 && [ "$(active role)" = inner ] &&
                fs hinge closed >/dev/null 2>&1 && [ "$(active role)" = cover ] || { fail "$tag cycle $cycle got stuck"; break; }
            [ "$cycle" = 10 ] && pass "$tag ten closed ↔ open cycles"
        done
    fi
    pose_check closed-portrait cover portrait 0
    corners
    rotate_check landscape-left
    corners
    rotate_check landscape-right
    rotate_check portrait-upside-down 3
    rotate_check portrait
    pose_check closed-landscape cover landscape-left 0
    pose_check tent cover landscape-right 75
    rotate_check landscape-left
    pose_check book inner landscape-left 110
    pose_check open-landscape inner landscape-left 180
    corners
    remember
    expect_exit "$tag swipe" 0 swipe 150 330 800 330 --duration 0.5
    sleep 0.8
    local path; path=$(touches | awk '$1 == "began" { b = $2 } $1 == "ended" { e = $2 } $1 == "moved" { m++ } END { print b, e, m + 0 }')
    set -- $path
    if near "${1:-0}" 150 3 && near "${2:-0}" 800 3 && [ "${3:-0}" -ge 5 ]; then pass "$tag swipe went 150 → 800 in $3 moves"; else fail "$tag swipe: '$path'"; fi
    remember
    expect_exit "$tag press" 0 press 475 300 --duration 1
    sleep 0.8
    local held; held=$(touches | awk '$1 == "began" { b = $4 } $1 == "ended" { e = $4 } END { print e - b }')
    if near "$held" 1.05 0.25; then pass "$tag press held ${held}s"; else fail "$tag press held '${held}' s"; fi
    pose_check open-portrait inner portrait 180
    corners
    rotate_check portrait-upside-down
    corners
    rotate_check landscape-right
    corners
    pose_check table inner portrait 110
    expect_exit "$tag screenshot both" 0 screenshot -o "$work/$tag-shot.png" --display both
    local cover inner; cover=$(png_size "$work/$tag-shot-cover.png"); inner=$(png_size "$work/$tag-shot-inner.png")
    case "$cover/$inner" in
        "1398 2034 /2007 2853 "|"2034 1398 /2007 2853 "|"1398 2034 /2853 2007 "|"2034 1398 /2853 2007 ") pass "$tag screenshots $cover/ $inner" ;;
        *) fail "$tag screenshot sizes '$cover' '$inner'" ;;
    esac
    expect_exit "$tag hinge 450 is clamped and settles" 0 hinge 450
    expect_exit "$tag tap outside the display" 2 tap 5000 10
    expect_exit "$tag unknown pose" 2 pose sideways
    launch portrait
    fs pose closed-portrait >/dev/null 2>&1
    rotate_check landscape-left 3
    [ "$(active orientation)" = portrait ] && pass "$tag stays portrait after the refusal" || fail "$tag left rotated after a refusal"
    launch gated
    rotate_check landscape-left
    fs rotate portrait >/dev/null 2>&1
    launch all
    tour_check 8
    teardown
}

flat() { # <tag> <device type> <tour steps>
    boot "$1" "$2" com.apple.CoreSimulator.SimRuntime.iOS-27-2 || return
    expect_exit "$tag doctor" 0 doctor
    [ "$(fs --json state 2>/dev/null | field 'd.get("hingeAngle", "none")')" = none ] && pass "$tag reports no hinge" || fail "$tag reports a hinge"
    expect_exit "$tag hinge is refused without a hinge" 2 hinge open
    launch all
    corners
    if [ "$tag" = iphone ]; then   # what a finger reaches: in portrait the status bar takes (30, 30), and
                                   # (12, 12) lies outside the rounded display corner; the edges take taps
        nothing_check 30 30
        nothing_check 12 12
        touch_check 30 80
        touch_check 12 478
    fi
    rotate_check landscape-left
    corners
    if [ "$tag" = iphone ]; then   # landscape has no status bar; the corner is still rounded
        touch_check 30 30
        nothing_check 12 12
    fi
    rotate_check landscape-right
    if [ "$tag" = ipad ]; then rotate_check portrait-upside-down; corners; else rotate_check portrait-upside-down 3; fi
    rotate_check portrait
    expect_exit "$tag screenshot" 0 screenshot -o "$work/$tag-shot.png"
    echo "     $tag screenshot $(png_size "$work/$tag-shot.png")"
    launch gated
    if [ "$tag" = ipad ]; then   # the iPad turns the app anyway: it ignores the run-time mask
        rotate_check landscape-left
    else
        rotate_check landscape-left 3
        [ "$(active orientation)" = portrait ] && pass "$tag gated app stays portrait" || fail "$tag gated app rotated"
    fi
    launch all
    tour_check "$3"
    teardown
}

tour_check() { # <steps>
    expect_exit "$tag tour" 0 tour --out "$work/$tag-tour" || return
    local shots ok
    shots=$(find "$work/$tag-tour" -name '*.png' | wc -l | tr -d ' ')
    ok=$(field '"%d %d" % (len(d["steps"]), sum(s["result"] == "ok" for s in d["steps"]))' < "$work/$tag-tour/tour.json")
    if [ "$ok" = "$1 $1" ] && [ -s "$work/$tag-tour/tour.md" ]; then pass "$tag tour: $1 steps, $shots screenshots"; else fail "$tag tour: steps/ok '$ok', $shots screenshots"; fi
}

trap '[ -n "$udid" ] && teardown' EXIT
echo "$("$foldsim" --version) · work directory $work"
"$foldsim" selftest >/dev/null && pass "selftest" || fail "selftest"
for target in "${@:-duo duo271 iphone ipad}"; do
    for device in $target; do
        case $device in
            duo) duo duo com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4 ;;
            duo271) duo duo271 com.apple.CoreSimulator.SimRuntime.iOS-27-1 ;;
            iphone) flat iphone com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro-Max 4 ;;
            ipad) flat ipad com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB 5 ;;
            *) echo "unknown device $device" ;;
        esac
    done
done
echo "$failed failed"
[ "$failed" = 0 ]
