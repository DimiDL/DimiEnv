#!/bin/bash

option0="UrlClassifierDbService:5"
option1="UrlClassifierDbService:5,nsChannelClassifier:5,UrlClassifierProtocolParser:5,UrlClassifierStreamUpdater:5,UrlClassifierPrefixSet:5"
option2="UrlClassifierDbService:5,nsChannelClassifier:5"
option3="ApplicationReputation:5"
option4="ApplicationReputation:5,HelperAppService:5"
option9=""

echo Enter MOZ_LOG options:
echo "(0. Basic) $option0"
echo "(1. Malware Protection) $option1"
echo "(2. Tracking Protection) $option2"
echo "(3. Download Protection) $option3"
echo "(4. Tmp) $option4"
echo "(8. MOZ_QUIET)"
echo "(9. Clear MOZ_LOG)"
read option

if [ $option == 0 ]
then
    export MOZ_LOG=$option0
elif [ $option == 1 ]
then
    export MOZ_LOG=$option1
elif [ $option == 2 ]
then
    export MOZ_LOG=$option2
elif [ $option == 3 ]
then
    export MOZ_LOG=$option3
elif [ $option == 4 ]
then
    export MOZ_LOG=$option4
elif [ $option == 8 ]
then
    export MOZ_QUIET=true
elif [ $option == 9 ]
then
    export MOZ_LOG=""
else
    echo "Wrong option, use default one"
    export MOZ_LOG="UrlClassifierDbService:5,nsChannelClassifier:5,UrlClassifierProtocolParser:5,UrlClassifierStreamUpdater:5,UrlClassifierPrefixSet:5"
fi
echo MOZ_LOG set to $MOZ_LOG
