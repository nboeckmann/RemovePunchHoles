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
	echo "#	 -h,    --help"
	echo "#"
	echo "# EXAMPLES"
	echo "#    removePunchHoles.sh -i <inputFilePath> -o <outputFilePath>"	
	
	exit
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
	esac
	shift
done

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
tmpDir="/scripts/ocrTmp/$UUID"
mkdir -p "$tmpDir"

echo "Extracting pages of inputFile"

/usr/bin/convert -type Palette "$inputFilePath" "$tmpDir/%d.tif"

files="$tmpDir/*.tif"

if [ "$verbose" -eq 0 ]; then
	echo -n "Working on page "
fi

for f in $files
do
	fileName=$(basename "$f")
	fileNameClean=${fileName%%.*}
	fileNameSmall="$fileNameClean-small.tif"
	fileNameSlice="$fileNameClean-slice.tif"
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

	if [ "$verbose" -eq 1 ]
	then
		echo "Working on page $(expr $fileNameClean + 1) percent=$percent percentFactor=$percentFactor percentFactorMult=$percentFactorMult x=$x y=$y xRes=$xRes yRes=$yRes xDim=$xDim yDim=$yDim xLeftBorderPx=$xLeftBorderPx yTopBorderPx=$yTopBorderPx xRightBorderPx=$xRightBorderPx yBottomBorderPx=$yBottomBorderPx"
	else
		echo -n "$(expr $fileNameClean + 1)"
	fi
	/usr/bin/convert -type Bilevel -type Grayscale -depth 1 -size "($(bc <<< "$xDimSmall"))"x"($(bc <<< "$yDimSmall"))" xc: -fill black -draw "translate $xDimSmallHalf,$yDimSmallHalf circle 0,0 $xDimSmallHalf,0" "$fileNameCircle"
	
	/usr/bin/convert -type Palette -resize "$percent"% "$f" "$tmpDir/$fileNameSmall"
	/usr/bin/convert -threshold 50% +repage -size "$xSmall"x"$ySmall" -depth 1 -extract "$xSmall"x"$ySmall+0+0" "$tmpDir/$fileNameSmall" "$tmpDir/$fileNameSlice"

	while : ; do
		compareResult=`/usr/bin/compare -metric mse -similarity-threshold $similarityThreshold -dissimilarity-threshold $dissimilarityThreshold -subimage-search "$tmpDir/$fileNameSlice" "$fileNameCircle" null: 2>&1`
		foundCoordinates=($(echo "$compareResult" | grep -o "@.*" | grep -o "[0-9]*"))
		if [ ${#foundCoordinates[@]} -eq 2 ]
		then
			findX=("${foundCoordinates[0]}")
			findY=("${foundCoordinates[1]}")

			findXSmall=($(printf %.2f $(echo "($findX + $xDimSmallHalf + ($xCorrection * $percentFactor))" | bc)))
			findYSmall=($(printf %.2f $(echo "($findY + $yDimSmallHalf + ($yCorrection * $percentFactor))" | bc)))

			xBig=($(printf %.2f $(echo "($findX * $percentFactorMult) + $xDimHalf + $xCorrection" | bc)))
			yBig=($(printf %.2f $(echo "($findY * $percentFactorMult) + $yDimHalf + $yCorrection" | bc)))

			leftBorderMatch=($(bc <<< "$xBig <= $xLeftBorderPx"))
			topBorderMatch=($(bc <<< "$yBig <= $yTopBorderPx"))
			rightBorderMatch=($(bc <<< "$xBig >= $xRightBorderPx"))
			bottomBorderMatch=($(bc <<< "$yBig >= $yBottomBorderPx"))

			fillRadius=($(bc <<< "$xDimHalf * $fillFactor"))

			/usr/bin/mogrify -type Palette -draw "fill white translate "$findXSmall,$findYSmall" circle 0,0 "$xDimSmallHalf,0"" "$tmpDir/$fileNameSlice"
			
			if [ $leftBorderMatch -eq 1 ] || [ $topBorderMatch -eq 1 ] || [ $rightBorderMatch -eq 1 ] || [ $bottomBorderMatch -eq 1 ]
			then
				if [ "$verbose" -eq 1 ]
				then
					echo -e "\t Match found: findX=$findX findY=$findY xBig=$xBig yBig=$yBig borderMatches=$leftBorderMatch,$topBorderMatch,$rightBorderMatch,$bottomBorderMatch"
				fi
				/usr/bin/mogrify -type Palette -draw "fill $replaceColor translate "$xBig,$yBig" circle 0,0 $fillRadius,0" "$f"
			else
				if [ "$verbose" -eq 1 ]
				then
					echo -e "\t Match found (filtered): findX=$findX findY=$findY xBig=$xBig yBig=$yBig borderMatches=$leftBorderMatch,$topBorderMatch,$rightBorderMatch,$bottomBorderMatch"
				fi
			fi

			if [ "$verbose" -eq 0 ] ; then
				echo -n "."
			fi
		else
			rm -f "$tmpDir/$fileNameSlice"
			rm -f "$tmpDir/$fileNameSmall"
			break
		fi
	done
done

if [ "$inputFilePath" == "$outputFilePath" ]
then
	rm -f "$inputFilePath"
fi

/usr/bin/convert -type Palette "$tmpDir/*.tif" "$outputFilePath"
rm -rf "$tmpDir"
echo "Done"
