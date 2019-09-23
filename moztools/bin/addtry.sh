#! /bin/bash

echo Enter TRY options:
echo "(1. All) try: -b do -p all -u all -t none"
echo "(2. Mochiterst) try: -b do -p all -u mochitests -t none"
echo "(3. None) try: -b do -p win32 -u none -t none"
echo "(4. Custom)"
read option

if [ $option == 1 ]
then
    SYNTAX="try: -b do -p all -u all -t none"
elif [ $option == 2 ]
then
    SYNTAX="try: -b do -p win32 -u none -t none"
elif [ $option == 3 ]
then
    SYNTAX="try: -b do -p all -u mochitests -t none"
elif [ $option == 4 ]
then
    echo "Please enter the syntax:"
    read custom_syntax
    SYNTAX=$custom_syntax
else
    echo "Unknown Input..."
    exit
fi

FILE="./try.txt"
echo $SYNTAX > $FILE

#git add $FILE
git add .
git commit -m "$SYNTAX"
git push try
