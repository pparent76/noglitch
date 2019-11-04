#!/bin/sh

# Copyright (C) 2017 Pierre Parent <pierre.parent ''at=- pparent.fr>
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

mkdir tmp
cd tmp

ffmpeg -i ../$1 -r 25 -s 1920x1080 -q:v  1 -qmin 1 -qmax 1 -b:v 500M outputFile_%d.jpg
ffmpeg -i ../$1 -vn -acodec flac output-audio.flac
framecount=$(ffmpeg -i ../$1 -map 0:v:0 -c copy -f null - 2>&1 | awk '/frame=/ {print $2}')

sensitivity=1200
sensitivityratio=100

next=0
value=0
previous=0
glitch=0;
correctprevious=0;
ratio1=0;
ratio2=0;
diffbetweendiffsabs=0;

for i in $( seq 1 $framecount ); do
previous=$value;
value=$next;
next=$(convert outputFile_$i.jpg -colorspace Gray -format "%[mean]" info: | sed "s/\..*//g")

diff1=$(( value - previous ))
diff2=$((  next - value ))

if [ "$previous" -ne "0" ]&& [ "$value" -ne "0" ]; then
ratio1=$(( (1000*value) / previous - 1000 ))
ratio2=$(( (1000*next) / value - 1000 ))
fi

if [ "$diff2" -ne "$diff1" ]; then
diffbetweendiffs=$((  (1000*(diff2 + diff1))/(diff2 - diff1) ))
else
    diffbetweendiffs=1000;
fi
#abs value
diffbetweendiffsabs=${diffbetweendiffs#-}

if [ "$correctprevious" -eq "0" ]; then
    
    if [ $diff1 -gt $sensitivity ]&&  [ $diff2 -lt -$sensitivity ] && [ $diffbetweendiffsabs -lt 250 ]; then
        echo "Correcting frame $(( i-1 )) $diff2  $diff1 $diffbetweendiffsabs";
        cp outputFile_$(( i-2 )).jpg outputFile_$(( i-1 )).jpg   
        glitch=1
        correctprevious=1;        
    fi

    if [ $diff2 -gt $sensitivity ]&&  [ $diff1 -lt -$sensitivity ] && [ $diffbetweendiffsabs -lt 250 ]; then
        echo "Correcting frame $(( i-1 ))  $diff2  $diff1 $diffbetweendiffsabs"
        cp outputFile_$(( i-2 )).jpg outputFile_$(( i-1 )).jpg
        glitch=1
        correctprevious=1;
    fi
    
    if [ "$ratio1" -gt $sensitivityratio ]&&  [ "$ratio2" -lt "-$sensitivityratio" ] && [ $diffbetweendiffsabs -lt 250 ]; then
        echo "Correcting frame $(( i-1 ))  $diff2  $diff1 $diffbetweendiffsabs"
        cp outputFile_$(( i-2 )).jpg outputFile_$(( i-1 )).jpg
        glitch=1
        correctprevious=1;
    fi
    
    if [ "$ratio2" -gt "$sensitivityratio" ]&&  [ "$ratio1" -lt "-$sensitivityratio" ] && [ $diffbetweendiffsabs -lt 250 ]; then
        echo "Correcting frame $(( i-1 ))  $diff2  $diff1 $diffbetweendiffsabs"
        cp outputFile_$(( i-2 )).jpg outputFile_$(( i-1 )).jpg
        glitch=1
        correctprevious=1;
    fi    
    
    # echo "frame $(( i-1 ))  $diff2  $diff1 $diffbetweendiffsabs $ratio1 $ratio2"
else
    correctprevious=0;
    
fi

done

if [ "$glitch" -eq "0" ]; then
    echo "No glitch found!"
else
    ffmpeg -r 25 -i outputFile_%d.jpg -i output-audio.flac -vcodec copy  ../out.avi
    echo "Glitch removed in out.avi"
fi
cd ..
rm -r tmp/
