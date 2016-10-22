#!/bin/bash -
#title          :removePunchHoles.sh
#description    :Tries to remove punch holes in scanned images
#author         :Nils Boeckmann
#date           :20161019
#version        :0.1
#usage          :./removePunchHoles.sh inputFileName outputFileName
#notes          :very early version of the script. Works very well with 300dpi color scans of a ScanJet 7000n
#copyright      :Copyright (c) http://www.boeckmanns.de - Nils Boeckmann
#license        :Apache License 2.0
#bash_version   :4.3.30(1)-release
#============================================================================

printUsage(){
	echo "# SYNOPSIS"
	echo "#    removePunchHoles.sh"
	echo "#"
	echo "# DESCRIPTION"
	echo "#    this script removes punch holes of images (TIF) passed to it"
	echo "#"
	echo "# OPTIONS"
	echo "#  -i,    --inputFile"
	echo "#	 -o,    --outputFilePath"
	echo "#	 -ff,   --fillFactor"
	echo "#	 -xc,   --xCorrection"
	echo "#	 -yc,   --yCorrection"
	echo "#	 -fc,   --fillColor"
	echo "#	 -pmd,  --punchMarkDiameter"
	echo "#	 -st,   --similarityThreshold"
	echo "#	 -dt,   --dissimilarityThreshold"
	echo "#	 -lb,   --leftBorder"
	echo "#	 -tb,   --topBorder"
	echo "#	 -rb,   --rightBorder"
	echo "#	 -bb,   --bottomBorder"
	echo "#	 -msis, --minSearchImageSize"
	echo "#	 -v,    --verbose"
	echo "#  -d,    --debug"
	echo "#	 -h,    --help"
	echo "#"
	echo "# EXAMPLES"
	echo "#    removePunchHoles.sh -i <inputFilePath> -o <outputFilePath>"	
	
	exit
}

removePunchHolesFromSlice(){
	mogrifyString=""
	
	while : ; do
		compareResult=`/usr/bin/compare -metric mse -similarity-threshold $similarityThreshold -dissimilarity-threshold $dissimilarityThreshold -subimage-search "$fileName" "$fileNameCircle" null: 2>&1`
		foundCoordinates=($(echo "$compareResult" | grep -o "@.*" | grep -o "[0-9]*"))
		if [ ${#foundCoordinates[@]} -eq 2 ]
		then
			findX=("${foundCoordinates[0]}")
			findY=("${foundCoordinates[1]}")

			findXSmall=($(printf %.2f $(echo "($findX + $xDimSmallHalf + ($xCorrection * $percentFactor))" | bc)))
			findYSmall=($(printf %.2f $(echo "($findY + $yDimSmallHalf + ($yCorrection * $percentFactor))" | bc)))

			xBig=($(printf %.2f $(echo "($findX * $percentFactorMult) + $xDimHalf + $xCorrection" + "$xOffset" | bc)))
			yBig=($(printf %.2f $(echo "($findY * $percentFactorMult) + $yDimHalf + $yCorrection" + "$yOffset" | bc)))

			fillRadius=($(bc <<< "$xDimHalf * $fillFactor"))
			
			/usr/bin/mogrify -type Palette -draw "fill white translate "$findXSmall,$findYSmall" circle 0,0 "$xDimSmallHalf,0"" "$fileName"
			
			if [ "$debug" -eq 1 ]
			then
				echo -e "\t Match found: findX=$findX findY=$findY xBig=$xBig yBig=$yBig"
			fi

			echo "fill $replaceColor ellipse $xBig,$yBig $fillRadius,$fillRadius 0,360" >> "$mvgName"
			
			if [ "$verbose" -eq 1 ] ; then
				echo -n "."
			fi
		else
			break
		fi
	done	
}

#---------------------------------------
#default config values
	fillFactor="1.5"
	xCorrection="0"
	yCorrection="0"
	replaceColor="white"

	punchMarkDiameterCm="0.55"
	similarityThreshold="0.2"
	dissimilarityThreshold="0.5"

	leftBorderCm="2.5"
	topBorderCm="2.5"
	rightBorderCm="2.5"
	bottomBorderCm="2.5"

	minSearchImagePx="3"

	verbose=0
	debug=0
	printUsage=0
#end of default config values
#--------------------------------------

while [[ $# -gt 0 ]]
do
	case "$1" in
		-i|--inputFile)
			inputFilePath="$2"
			shift 1
			;;
		-o|--outputFile)
			outputFilePath="$2"
			shift 1
			;;
		-ff|--fillFactor)
			fillFactor="$2"
			shift 1
			;;
		-xc|--xCorrection)
			xCorrection="$2"
			shift 1
			;;
		-yc|--yCorrection)
			yCorrection="$2"
			shift 1
			;;
		-fc|--fillColor)
			replaceColor="$2"
			shift 1
			;;
		-pmd|--punchMarkDiameter)
			punchMarkDiameterCm="$2"
			shift 1
			;;
		-st|--similarityThreshold)
			similarityThreshold="$2"
			shift 1
			;;
		-dt|--dissimilarityThreshold)
			dissimilarityThreshold="$2"
			shift 1
			;;
		-lb|--leftBorder)
			leftBorderCm="$2"
			shift 1
			;;
		-tb|--topBorder)
			topBorderCm="$2"
			shift 1
			;;
		-rb|--rightBorder)
			rightBorderCm="$2"
			shift 1
			;;
		-bb|--bottomBorderCm="$2")
			bottomBorderCm="$2"
			shift 1
			;;
		-msis|--minSearchImageSize)
			minSearchImagePx="$2"
			shift 1
			;;
		-v|--verbose)
			verbose=1
			;;
		-h|--help)
			printUsage
			;;
		-d|--debug)
			verbose=0
			debug=1
			;;
	esac
	shift
done

if [ "$verbose" -eq 1 ] && [ "$debug" -eq 1 ] ; then
	verbose=0
fi

if [ -z "$inputFilePath" ]
then
	echo "please provide input file"
	exit
fi

if ! [ -r "$inputFilePath" ]
then
	echo "please provide valid inputFile"
	exit
fi

UUID=$(cat /proc/sys/kernel/random/uuid)
tmpDir="/tmp/ocrTmp/$UUID"
mkdir -p "$tmpDir"

if [ "$verbose" -eq 1 ] || [ "$debug" -eq 1 ] ; then
	echo "Extracting pages of inputFile"
fi

/usr/bin/convert -type Palette "$inputFilePath" "$tmpDir/%d.tif"

files="$tmpDir/*.tif"

if [ "$verbose" -eq 1 ]; then
	echo -n "Working on page "
fi

for f in $files
do
	fileName=$(basename "$f")
	fileNameClean=${fileName%%.*}
	fileNameSmall="$fileNameClean-small.tif"
	fileNameSlice="$fileNameClean-slice.tif"

	fileNameSliceL="$fileNameClean-sliceL.tif"
	fileNameSliceT="$fileNameClean-sliceT.tif"
	fileNameSliceR="$fileNameClean-sliceR.tif"
	fileNameSliceB="$fileNameClean-sliceB.tif"

	fileNameCircle="$tmpDir/circleSmall.png"
	tifInfo=`/usr/bin/identify -verbose "$f"`
	dimensions=($(echo "$tifInfo" | grep "Geometry:" | awk {'print $2'} | grep -o "[0-9]*"))
	resolution=($(echo "$tifInfo" | grep "Resolution:" | awk {'print $2'} | grep -o "[0-9]*"))

	x=("${dimensions[0]}")
	y=("${dimensions[1]}")

	xRes=("${resolution[0]}")
	yRes=("${resolution[1]}")

	#determining the optimal shrink factor to speed the process up as much as possible
	percent="1"
	while : ; do
	    percentFactor=($(printf %.2f $(echo "$percent / 100" | bc -l)))
		percentFactorMult=($(printf %.2f $(echo "100 / $percent" | bc -l)))
		xSmall=($(printf %.2f $(echo "$x * $percentFactor" | bc -l)))
		ySmall=($(printf %.2f $(echo "$y * $percentFactor" | bc -l)))

		xLeftBorderPx=($(printf %.0f $(echo "($leftBorderCm / 2.54 * $xRes)" | bc -l)))
		yTopBorderPx=($(printf %.0f $(echo "($topBorderCm / 2.54 * $xRes)" | bc -l)))
		xRightBorderPx=($(printf %.0f $(echo "($x - ($rightBorderCm / 2.54 * $xRes))" | bc -l)))
		yBottomBorderPx=($(printf %.0f $(echo "($y - ($bottomBorderCm / 2.54 * $xRes))" | bc -l)))

		xDim=($(printf %.2f $(echo "($punchMarkDiameterCm / 2.54 * $xRes)" | bc -l)))
	        yDim=($(printf %.2f $(echo "($punchMarkDiameterCm / 2.54 * $yRes)" | bc -l)))

		xDimHalf=($(printf %.2f $(echo "$xDim * 0.5" | bc -l)))
		yDimHalf=($(printf %.2f $(echo "$yDim * 0.5" | bc -l)))

		xDimSmall=($(printf %.2f $(echo "($xDim * $percentFactor) + 0.5" | bc -l)))
		yDimSmall=($(printf %.2f $(echo "($yDim * $percentFactor) + 0.5" | bc -l)))
		xDimSmallHalf=($(printf %.2f $(echo "($xDimSmall * 0.5) - 0.5" | bc -l)))
		yDimSmallHalf=($(printf %.2f $(echo "($yDimSmall * 0.5) - 0.5" | bc -l)))

		if (( ($(bc <<< "$xDimSmallHalf >= $minSearchImagePx")) ))
		then
			break
		fi
		percent=($(bc <<< "$percent + 1"))
	done

	if [ "$debug" -eq 1 ] ; then
		echo "Working on page $(expr $fileNameClean + 1) percent=$percent percentFactor=$percentFactor percentFactorMult=$percentFactorMult x=$x y=$y xRes=$xRes yRes=$yRes xDim=$xDim yDim=$yDim xLeftBorderPx=$xLeftBorderPx yTopBorderPx=$yTopBorderPx xRightBorderPx=$xRightBorderPx yBottomBorderPx=$yBottomBorderPx"
	fi
	
	if [ "$verbose" -eq 1 ] ; then
		echo -n "$(expr $fileNameClean + 1)"
	fi

	/usr/bin/convert -type Bilevel -type Grayscale -depth 1 -size "($(bc <<< "$xDimSmall"))"x"($(bc <<< "$yDimSmall"))" xc: -fill black -draw "translate $xDimSmallHalf,$yDimSmallHalf circle 0,0 $xDimSmallHalf,0" "$fileNameCircle"
	
	/usr/bin/convert -type Palette -resize "$percent"% "$f" "$tmpDir/$fileNameSmall"
	#/usr/bin/convert -threshold 50% +repage -size "$xSmall"x"$ySmall" -depth 1 -extract "$xSmall"x"$ySmall+0+0" "$tmpDir/$fileNameSmall" "$tmpDir/$fileNameSlice"

	xOffset="0"
	yOffset="0"
	fileName=""
	mvgName="$tmpDir/punchHoles.mvg"

	#left	
	if ! [ $leftBorderCm == "0" ] ; then
		/usr/bin/convert -threshold 50% +repage -size "$(bc -l <<< "$xLeftBorderPx * $percentFactor")"x"$ySmall" -depth 1 -extract "$(bc -l <<< "$xLeftBorderPx * $percentFactor")"x"$ySmall+0+0" "$tmpDir/$fileNameSmall" "$tmpDir/$fileNameSliceL"
		xOffset="0"
		yOffset="0"
		fileName="$tmpDir/$fileNameSliceL"
		removePunchHolesFromSlice
		rm -f "$tmpDir/$fileNameSliceL"
	fi
	
	#top
	if ! [ $topBorderCm == "0" ] ; then
		/usr/bin/convert -threshold 50% +repage -size "$xSmall"x"$(bc -l <<< "$yTopBorderPx * $percentFactor")" -depth 1 -extract "$xSmall"x"$(bc -l <<< "$yTopBorderPx * $percentFactor")+0+0" "$tmpDir/$fileNameSmall" "$tmpDir/$fileNameSliceT"	
		xOffset="0"
		yOffset="0"
		fileName="$tmpDir/$fileNameSliceT"
		removePunchHolesFromSlice
		rm -f "$tmpDir/$fileNameSliceT"
	fi
	
	#right
	if ! [ $rightBorderCm == "0" ] ; then
		/usr/bin/convert -threshold 50% +repage -size "$(bc -l <<< "$xLeftBorderPx * $percentFactor")"x"$ySmall" -depth 1 -extract "$(bc -l <<< "$xLeftBorderPx * $percentFactor")"x"$ySmall+$(bc -l <<< "$xRightBorderPx * $percentFactor")+0" "$tmpDir/$fileNameSmall" "$tmpDir/$fileNameSliceR"
		xOffset="$xRightBorderPx"
		yOffset="0"
		fileName="$tmpDir/$fileNameSliceR"
		removePunchHolesFromSlice
		rm -f "$tmpDir/$fileNameSliceR"
	fi
	
	#bottom
	if ! [ $bottomBorderCm == "0" ] ; then
		/usr/bin/convert -threshold 50% +repage -size "$xSmall"x"$(bc -l <<< "$yTopBorderPx * $percentFactor")" -depth 1 -extract "$xSmall"x"$(bc -l <<< "$yTopBorderPx * $percentFactor")+0+$(bc -l <<< "$yBottomBorderPx * $percentFactor")" "$tmpDir/$fileNameSmall" "$tmpDir/$fileNameSliceB"
		xOffset="0"
		yOffset="$yBottomBorderPx"
		fileName="$tmpDir/$fileNameSliceB"
		removePunchHolesFromSlice
		rm -f "$tmpDir/$fileNameSliceB"
	fi
	
	if [ -s "$mvgName" ] ; then
		/usr/bin/mogrify -type Palette -draw "@$mvgName" "$f"
	fi
	
	rm -f "$mvgName"
	rm -f "$tmpDir/$fileNameSmall"
done

if [ "$inputFilePath" == "$outputFilePath" ]
then
	rm -f "$inputFilePath"
fi

/usr/bin/convert -type Palette "$tmpDir/*.tif" "$outputFilePath"
rm -rf "$tmpDir"

if [ "$verbose" -eq 1 ] || [ "$debug" -eq 1 ] ; then
	echo "Done"
fi
