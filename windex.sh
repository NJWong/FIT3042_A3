#!/bin/bash

printf "\n------ START windex.sh ------\n\n"

# ----- START Script Setup ------ #

# Check NAME is provided
if [ -z "$1" ]
	then
		printf "NAME not given\n"
		exit 1;
fi

# Check WORD is provided
if [ -z "$2" ]
	then
		printf "WORD not given\n"
		exit 1;
fi

# Set variables to the passed in parameters
NAME=$1
WORD=$2

# Check if DIRECTORY is (optionally) provided
if [ -z "$3" ]
	# Set to default value - the current working directory
	then
		DIR=$PWD
else
	DIR=$3
fi

# Create filepath
FP="${DIR}/${NAME}"

# Check that the directory/file path exists
if [ -e $FP ]
	then
		printf "Valid path: \"${FP}\"\n\n"
else
	printf "Invalid path: \"${FP}\"\n"
	exit 1;
fi

# ------ END Script Setup ------ #

# ------ START Main ------ #

PATTERN="${WORD},"

RESULT=$(grep -E "\b${PATTERN}" ${FP})

echo $RESULT | tr "," "\n"

# ------ END Main ------ #

printf "\n------ END windex.sh ------\n"