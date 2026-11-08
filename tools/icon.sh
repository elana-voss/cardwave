#!/bin/sh
# Writes desktop/icons from the board "Installer and desktop icon" (design/InstallerIcon.dc.html) with
# ImageMagick (`magick`, its librsvg renderer). Run from anywhere; running it again writes the same files.
#
# The drawings are the board's SVG, copied here: the full bubble (32 px and up) and the simpler 16 px one. Out:
# icon.ico (16, 32, 48, 256), Tauri's 32x32.png, 128x128.png, 128x128@2x.png, and the installer's sidebar.bmp
# (164 x 314) and header.bmp (150 x 57), each also as @2x.bmp, which desktop/installer.nsh picks on a screen
# at 150 % or more.
#
# Traps: "Cardwave" is Geist Bold as a path (WORD), so no font is needed: shaped with kerning by HarfBuzz from
# web's @fontsource-variable/geist at wght 700, in font units (1000 per em, baseline at 0, 4894 wide); its
# place copies the board's CSS (line-height 1.5, so the baseline sits 1.105 em below the line's top). NSIS
# reads only 24-bit BMP, hence BMP3 without alpha. PNGs are PNG32, or ImageMagick picks a palette.
set -e
# magick is a Windows program: the paths are given it in its form (`pwd -W`, Git Bash).
ROOT="$(cd "$(dirname "$0")/.." && (pwd -W 2>/dev/null || pwd))"
ICONS="$ROOT/desktop/icons"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

FULL='<path d="M24 20h80a14 14 0 0 1 14 14v44a14 14 0 0 1-14 14H54l-22 20v-20h-8a14 14 0 0 1-14-14V34a14 14 0 0 1 14-14z" fill="#0083E9" stroke="#FFFFFF" stroke-width="6" stroke-linejoin="round"/><path d="M64 34C66 50 70 54 86 56C70 58 66 62 64 78C62 62 58 58 42 56C58 54 62 50 64 34Z" fill="#FFFFFF"/>'
SMALL='<path d="M14 14h100v76H58l-30 26V90H14z" fill="#0083E9" stroke="#FFFFFF" stroke-width="10" stroke-linejoin="round"/><path d="M64 30C67 50 70 53 90 56C70 59 67 62 64 82C61 62 58 59 38 56C58 53 61 50 64 30Z" fill="#FFFFFF"/>'
WORD='M375 16Q278 16 203 -28Q127 -72 85 -155Q42 -238 42 -354Q42 -467 83 -551Q124 -634 200 -680Q276 -726 378 -726Q517 -726 594 -657Q672 -589 694 -462L536 -456Q524 -523 484 -561Q444 -598 378 -598Q321 -598 281 -568Q241 -538 220 -483Q199 -428 199 -354Q199 -279 220 -225Q242 -170 282 -141Q322 -112 377 -112Q449 -112 488 -152Q528 -193 538 -265L697 -259Q683 -172 642 -111Q601 -50 534 -17Q468 16 375 16ZM950 12Q867 12 814 -27Q762 -65 762 -134Q762 -205 806 -243Q851 -282 938 -300L1111 -334Q1111 -386 1087 -413Q1064 -439 1020 -439Q977 -439 953 -420Q929 -400 922 -362L771 -369Q786 -457 851 -503Q915 -548 1020 -548Q1140 -548 1200 -491Q1261 -434 1261 -324V-141Q1261 -118 1268 -111Q1276 -103 1291 -103H1306V0Q1299 2 1284 4Q1268 6 1253 6Q1221 6 1193 -5Q1166 -16 1149 -43Q1132 -69 1132 -118L1145 -108Q1135 -72 1110 -45Q1084 -18 1043 -3Q1003 12 950 12ZM986 -91Q1023 -91 1051 -106Q1079 -120 1095 -148Q1111 -176 1111 -214V-240L989 -214Q953 -207 934 -191Q916 -174 916 -148Q916 -121 934 -106Q952 -91 986 -91ZM1385 0V-536H1527L1532 -380L1521 -383Q1534 -464 1567 -500Q1600 -536 1658 -536H1707V-412H1658Q1616 -412 1589 -401Q1562 -390 1548 -366Q1535 -342 1535 -301V0ZM1961 12Q1893 12 1844 -22Q1794 -57 1768 -119Q1741 -182 1741 -268Q1741 -354 1768 -416Q1795 -479 1844 -514Q1894 -548 1961 -548Q2018 -548 2059 -525Q2101 -501 2122 -460V-710H2272V0H2129L2126 -79Q2104 -36 2060 -12Q2017 12 1961 12ZM2010 -103Q2046 -103 2071 -122Q2096 -141 2109 -177Q2122 -214 2122 -268Q2122 -323 2109 -359Q2096 -396 2071 -414Q2046 -433 2010 -433Q1957 -433 1926 -389Q1895 -344 1895 -268Q1895 -193 1927 -148Q1958 -103 2010 -103ZM2508 0 2349 -536H2500L2592 -173L2691 -536H2813L2912 -173L3005 -536H3156L2997 0H2851L2752 -335L2653 0ZM3373 12Q3290 12 3237 -27Q3185 -65 3185 -134Q3185 -205 3229 -243Q3274 -282 3361 -300L3534 -334Q3534 -386 3510 -413Q3487 -439 3443 -439Q3400 -439 3376 -420Q3352 -400 3345 -362L3194 -369Q3209 -457 3274 -503Q3338 -548 3443 -548Q3563 -548 3623 -491Q3684 -434 3684 -324V-141Q3684 -118 3691 -111Q3699 -103 3714 -103H3729V0Q3722 2 3707 4Q3691 6 3676 6Q3644 6 3616 -5Q3589 -16 3572 -43Q3555 -69 3555 -118L3568 -108Q3558 -72 3533 -45Q3507 -18 3466 -3Q3426 12 3373 12ZM3409 -91Q3446 -91 3474 -106Q3502 -120 3518 -148Q3534 -176 3534 -214V-240L3412 -214Q3376 -207 3357 -191Q3339 -174 3339 -148Q3339 -121 3357 -106Q3375 -91 3409 -91ZM3925 0 3729 -536H3886L4013 -151L4139 -536H4296L4099 0ZM4596 12Q4514 12 4453 -23Q4393 -57 4359 -120Q4326 -183 4326 -268Q4326 -353 4359 -415Q4393 -478 4453 -513Q4513 -548 4595 -548Q4675 -548 4734 -513Q4793 -478 4825 -413Q4858 -348 4858 -258V-228H4481Q4484 -164 4516 -133Q4547 -102 4599 -102Q4637 -102 4663 -118Q4688 -134 4699 -167L4850 -158Q4829 -78 4761 -33Q4693 12 4596 12ZM4481 -320H4704Q4701 -379 4672 -408Q4642 -437 4595 -437Q4548 -437 4518 -406Q4487 -376 4481 -320Z'

# svg FILE W H PIXELS-PER-UNIT BODY: an SVG of W x H units, drawn at that many pixels per unit.
svg() {
  printf '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="0 0 %s %s">%s</svg>' \
    "$(awk "BEGIN{print $2 * $4}")" "$(awk "BEGIN{print $3 * $4}")" "$2" "$3" "$5" > "$1"
}

# The icon at N px: the 16 px drawing at 16, the full one above.
for n in 16 32 48 256; do
  if [ "$n" = 16 ]; then body="$SMALL"; else body="$FULL"; fi
  svg "i$n.svg" 128 128 "$(awk "BEGIN{print $n / 128}")" "$body"
  magick -background none "i$n.svg" "PNG32:i$n.png"
done
svg i128.svg 128 128 1 "$FULL"
magick -background none i128.svg "PNG32:$ICONS/128x128.png"
magick i16.png i32.png i48.png i256.png "$ICONS/icon.ico"
cp i32.png "$ICONS/32x32.png"
cp i256.png "$ICONS/128x128@2x.png"

# icon X Y SIZE / word X BASELINE SIZE: the full icon and the word, placed in board pixels.
icon() { printf '<g transform="translate(%s %s) scale(%s)">%s</g>' "$1" "$2" "$(awk "BEGIN{print $3/128}")" "$FULL"; }
word() { printf '<path transform="translate(%s %s) scale(%s)" fill="#111111" d="%s"/>' "$1" "$2" "$(awk "BEGIN{print $3/1000}")" "$WORD"; }

# Side picture: a column of the 72 px icon, 14 px, and a 30 px line of 20 px text, centred in 164 x 314.
SIDE="<rect width=\"164\" height=\"314\" fill=\"#F4F4F5\"/>$(icon 46 99 72)$(word 33.06 207.1 20)"
# Header picture: the 30 px icon, 8 px, and 14 px text, right-aligned 8 px from the edge, on white.
HEAD="<rect width=\"150\" height=\"57\" fill=\"#FFFFFF\"/>$(icon 35.48 13.5 30)$(word 73.48 33.47 14)"
for s in 1 2; do
  if [ "$s" = 1 ]; then x=""; else x="@2x"; fi
  svg side.svg 164 314 "$s" "$SIDE"
  svg head.svg 150 57 "$s" "$HEAD"
  magick side.svg -alpha off -type truecolor "BMP3:$ICONS/sidebar$x.bmp"
  magick head.svg -alpha off -type truecolor "BMP3:$ICONS/header$x.bmp"
done
