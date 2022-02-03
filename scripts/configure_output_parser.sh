#!/bin/bash

INPUT_FILE="$1"
COMPLETE_LIST_OF_CHECKS=
EVERYTHING_ELSE=
ERROR_CHECKS=
COMPLETE_LIST_OF_HEADERS=
COMPLETE_LIST_OF_HEADERS_YES=
COMPLETE_LIST_OF_HEADERS_NO=
COMPLETE_LIST_OF_LIBRARIES=
COMPLETE_LIST_OF_LIBRARIES_YES=
COMPLETE_LIST_OF_LIBRARIES_NO=
COMPLETE_LIST_OF_EXECUTABLES=
COMPLETE_LIST_OF_EXECUTABLES_YES=
COMPLETE_LIST_OF_EXECUTABLES_NO=
COMPLETE_LIST_OF_FUNCTIONS=
COMPLETE_LIST_OF_FUNCTIONS_YES=
COMPLETE_LIST_OF_FUNCTIONS_NO=


# Generate a complete list of all checks by selecting the relevant 'checking for ' lines in the 'configure' script output
while IFS=$'\n' read -r LINE
do
    #echo $LINE
    if [[ "$LINE" =~ 'checking for ' ]]
    then
        LINE=$(echo "$LINE" | sed -E 's/checking for //')
        #echo "This line matches the regexp for the complete list of 'checking for lines': $LINE"
        COMPLETE_LIST_OF_CHECKS+=$LINE$'\n'
        #echo "Line after clean-up is now: $LINE"

        # NEW PLACE FOR ALL CHECKS
        if [[ "$LINE" =~ '.h.' ]]
        then
            #echo "This line matches the regexp to detect header files: $LINE"
            # remove all other text before the name of the header file (if present)
            LINE=$(echo "$LINE" | sed -E s'/[a-zA-Z0-9\/_()]+( declared)? in //')
            #echo "Line after clean-up is now: $LINE"
            TEMPLINE+=$(echo "$LINE" | sed -E 's/\.{3}( \(cached\))? (yes|no)//')$'\n'
            #echo "Complete list of headers line is $LINE"
            if [[ -n $TEMPLINE ]]
            then
                #echo "Complete list of libraries line is $LINE"
                COMPLETE_LIST_OF_HEADERS+="$TEMPLINE"$'\n'
            fi
            if [[ "$LINE" =~ yes$ ]]
            then
                #echo "This line matches the regexp for an installed header file: $LINE"
                LINE=$(echo "$LINE" | sed -E 's/\.{3}( \(cached\))? yes//')
                #echo "Line after clean-up is now: $LINE"
                COMPLETE_LIST_OF_HEADERS_YES+="$LINE"$'\n'
                continue
            elif [[ "$LINE" =~ no$ ]]
            then
                #echo "This line matches the regexp for a missing header file: $LINE"
                LINE=$(echo "$LINE" | sed -E 's/\.{3} no//')
                #echo "Line after clean-up is now: $LINE"
                COMPLETE_LIST_OF_HEADERS_NO+="$LINE"$'\n'
                continue
            else
                echo "WARNING: This line remains unmatched when separating the installed from the missing header files: $LINE"
                ERROR_CHECKS+="$LINE"$'\n'
                continue
            fi
        elif  [[ "$LINE" =~ ' -l' ]]
        then
            #echo "This is the library line before modification: $LINE"
            # remove all other text before the name of the library file (if present)
            #LINE=$(echo "$LINE" | sed 's///')
            LINE=$(echo "$LINE" | sed -E 's/.* in -l//')
            #echo "This is the library line after pre-text modification: $LINE" 
            TEMPLINE=$(echo "$LINE" | sed -E 's/\.{3}( \(cached\))? (yes|no)//')
            #echo "This is the library line after post-text modification: $TEMPLINE"
            #echo "Complete list of libraries line (before non-zero check) is $TEMPLINE"
            if [[ -n $TEMPLINE ]]
            then
                #echo "Complete list of libraries line (after non-zero check) is $TEMPLINE"
                COMPLETE_LIST_OF_LIBRARIES+="$TEMPLINE"$'\n'
            fi
            if [[ "$LINE" =~ yes$ ]]
            then
                #echo "This line matches the regexp for an installed library file: $LINE"
                LINE=$(echo "$LINE" | sed -E 's/\.{3}( \(cached\))? yes//')
                #LINE=$(echo "$LINE" | sed -E 's/.* in -l//')
                #echo "Line after clean-up is now: $LINE"
                COMPLETE_LIST_OF_LIBRARIES_YES+="$LINE"$'\n'
            elif [[ "$LINE" =~ no$ ]]
            then
                #echo "This line matches the regexp for a missing library file: $LINE"
                LINE=$(echo "$LINE" | sed -E 's/\.{3}( \(cached\))? no//')
                #LINE=$(echo "$LINE" | sed -E 's/.* in -l//')
                #echo "Line after clean-up is now: $LINE"
                COMPLETE_LIST_OF_LIBRARIES_NO+="$LINE"$'\n'
            else
                echo "WARNING: This line remains unmatched when separating the installed from the missing library files: $LINE"
                ERROR_CHECKS+="$LINE"$'\n'
            fi
        elif [[ "$LINE" =~ ^[[:alnum:]/]+[[:alnum:]/_-]+\.{3} ]]
        then
            # Filter out installed functions
            if [[ "$LINE" =~ yes$ ]]
            then
                #echo "This line matches the regexp for an installed library function: $LINE"
                LINE=$(echo "$LINE" | sed -E 's/\.{3}( \(cached\))? yes//')
                COMPLETE_LIST_OF_FUNCTIONS+="$LINE"$'\n'
                #echo "Line after clean-up is now: $LINE"
                COMPLETE_LIST_OF_FUNCTIONS_YES+="$LINE"$'\n'
            # Filter out missing functions
            elif [[ "$LINE" =~ no$ ]]
            then
                #echo "This line matches the regexp for a missing library function: $LINE"
                LINE=$(echo "$LINE" | sed -E 's/\.{3} no//')
                COMPLETE_LIST_OF_FUNCTIONS+="$LINE"$'\n'
                #echo "Line after clean-up is now: $LINE"
                COMPLETE_LIST_OF_FUNCTIONS_NO+="$LINE"$'\n'
            # Filter out installed executables
            elif [[ "$LINE" =~ /s?bin ]]
            then
                # Add line to COMPLETE_LIST_OF_EXECUTABLES but do not remove extraneous text yet (for debugging purposes)
                COMPLETE_LIST_OF_EXECUTABLES+="$LINE"$'\n'
                #echo "This line matches the regexp for an installed executable file: $LINE"
                LINE=$(echo "$LINE" | sed -E 's/\.{3}( \(cached\))? \/((s?bin)|usr).*//')
                #echo "Line after clean-up is now: $LINE"
                COMPLETE_LIST_OF_EXECUTABLES_YES+="$LINE"$'\n'
            # Filter out missing executables
            elif [[ "$LINE" =~ :$ ]]
            then
                # Add line to COMPLETE_LIST_OF_EXECUTABLES but do not remove extraneous text yet (for debugging purposes)
                COMPLETE_LIST_OF_EXECUTABLES+="$LINE"$'\n'
                #echo "This line matches the regexp for a missing executable file: $LINE"
                LINE=$(echo "$LINE" | sed -E 's/\.{3} :$//')
                #echo "Line after clean-up is now: $LINE"
                COMPLETE_LIST_OF_EXECUTABLES_NO+="$LINE"$'\n'
            # Catch everything else (this is an error if anything makes it this far)
            else
                #echo "This line does not match the regexp for an executable file or library function whether installed or missing: $LINE"
                ERROR_CHECKS+="$LINE"$'\n'
            fi
        else
            #echo "This line does not match the regexp for a single-word executable file or library function: $LINE"
            ERROR_CHECKS+="$LINE"$'\n'
        fi

    else # 'checking for'
        #echo "This line does not match the regexp for the complete list of 'checking for' lines: $LINE"
        EVERYTHING_ELSE+="$LINE"$'\n'
    fi
done < "$INPUT_FILE"

COMPLETE_LIST_OF_HEADERS=$(echo "$COMPLETE_LIST_OF_HEADERS" | sort -u)
COMPLETE_LIST_OF_HEADERS_YES=$(echo "$COMPLETE_LIST_OF_HEADERS_YES" | sort -u)
COMPLETE_LIST_OF_HEADERS_NO=$(echo "$COMPLETE_LIST_OF_HEADERS_NO" | sort -u)
COMPLETE_LIST_OF_LIBRARIES=$(echo "$COMPLETE_LIST_OF_LIBRARIES" | sort -u)
COMPLETE_LIST_OF_LIBRARIES_YES=$(echo "$COMPLETE_LIST_OF_LIBRARIES_YES" | sort -u)
COMPLETE_LIST_OF_LIBRARIES_NO=$(echo "$COMPLETE_LIST_OF_LIBRARIES_NO" | sort -u)
COMPLETE_LIST_OF_EXECUTABLES=$(echo "$COMPLETE_LIST_OF_EXECUTABLES" | sort -u)
COMPLETE_LIST_OF_EXECUTABLES_YES=$(echo "$COMPLETE_LIST_OF_EXECUTABLES_YES" | sort -u)
COMPLETE_LIST_OF_EXECUTABLES_NO=$(echo "$COMPLETE_LIST_OF_EXECUTABLES_NO" | sort -u)
COMPLETE_LIST_OF_FUNCTIONS=$(echo "$COMPLETE_LIST_OF_FUNCTIONS" | sort -u)
COMPLETE_LIST_OF_FUNCTIONS_YES=$(echo "$COMPLETE_LIST_OF_FUNCTIONS_YES" | sort -u)
COMPLETE_LIST_OF_FUNCTIONS_NO=$(echo "$COMPLETE_LIST_OF_FUNCTIONS_NO" | sort -u)
ERROR_CHECKS=$(echo "$ERROR_CHECKS" | sort -u)

# Remove entries that appear both in the installed and uninstalled lists of headers
DUPLICATE_HEADERS=0
TEMP_COMPLETE_LIST_OF_HEADERS_NO="$COMPLETE_LIST_OF_HEADERS_NO"
COMPLETE_LIST_OF_HEADERS_NO=''
for item in $TEMP_COMPLETE_LIST_OF_HEADERS_NO
do
  if ! [[ $COMPLETE_LIST_OF_HEADERS_YES =~ $item ]]
  then
    COMPLETE_LIST_OF_HEADERS_NO+=$item$'\n'
  else
    echo "Not adding the following to the list of uninstalled headers: $item"
    (( DUPLICATE_HEADERS++ ))
  fi
done
echo "Removed $DUPLICATE_HEADERS header files that appeared in both the lists of installed and missing header files."

# Remove entries that appear both in the installed and uninstalled lists of libraries
DUPLICATE_LIBRARIES=0
TEMP_COMPLETE_LIST_OF_LIBRARIES_NO="$COMPLETE_LIST_OF_LIBRARIES_NO"
COMPLETE_LIST_OF_LIBRARIES_NO=''
for item in $TEMP_COMPLETE_LIST_OF_LIBRARIES_NO
do
  if ! [[ $COMPLETE_LIST_OF_LIBRARIES_YES =~ $item ]]
  then
    COMPLETE_LIST_OF_LIBRARIES_NO+=$item$'\n'
  else
    echo "Not adding the following to the list of uninstalled libraries: $item"
    (( DUPLICATE_LIBRARIES++ ))
  fi
done
echo "Removed $DUPLICATE_LIBRARIES library files that appeared in both the lists of installed and missing library files."

# Remove entries that appear both in the installed and uninstalled lists of executables
DUPLICATE_EXECUTABLES=0
TEMP_COMPLETE_LIST_OF_EXECUTABLES_NO="$COMPLETE_LIST_OF_EXECUTABLES_NO"
COMPLETE_LIST_OF_EXECUTABLES_NO=''
for item in $TEMP_COMPLETE_LIST_OF_EXECUTABLES_NO
do
  if ! [[ $COMPLETE_LIST_OF_EXECUTABLES_YES =~ $item ]]
  then
    COMPLETE_LIST_OF_EXECUTABLES_NO+=$item$'\n'
  else
    echo "Not adding the following to the list of uninstalled executables: $item"
    (( DUPLICATE_EXECUTABLES+=1 ))
  fi
done
echo "Removed $DUPLICATE_EXECUTABLES executables that appeared in both the lists of installed and missing executables."

# Remove entries that appear both in the installed and uninstalled lists of functions:
DUPLICATE_FUNCTIONS=0
TEMP_COMPLETE_LIST_OF_FUNCTIONS_NO="$COMPLETE_LIST_OF_FUNCTIONS_NO"
COMPLETE_LIST_OF_FUNCTIONS_NO=''
for item in $TEMP_COMPLETE_LIST_OF_FUNCTIONS_NO
do
  if ! [[ $COMPLETE_LIST_OF_FUNCTIONS_YES =~ $item ]]
  then
    COMPLETE_LIST_OF_FUNCTIONS_NO+=$item$'\n'
  else
    echo "Not adding the following to the list of uninstalled functions: $item"
    (( DUPLICATE_FUNCTIONS+=1 ))
  fi
done
echo "Removed $DUPLICATE_FUNCTIONS functions that appeared in both the lists of installed and missing functions."

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "Complete list of checks"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$COMPLETE_LIST_OF_CHECKS"
# echo " "

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "Lines that did not match as relevant checks"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$EVERYTHING_ELSE"
# echo " "

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "Complete list of headers"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$COMPLETE_LIST_OF_HEADERS"
# echo "Total of $(echo -e $COMPLETE_LIST_OF_HEADERS | wc -w) headers"
# echo " "

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "List of headers already installed"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$COMPLETE_LIST_OF_HEADERS_YES"
# echo "Total of $(echo -e $COMPLETE_LIST_OF_HEADERS_YES | wc -w) headers"
# echo " "

echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo "List of headers that need to be installed"
echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo -e "$COMPLETE_LIST_OF_HEADERS_NO"
echo "Total of $(echo -e $COMPLETE_LIST_OF_HEADERS_NO | wc -w) headers"
echo " "

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "Complete list of libraries"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$COMPLETE_LIST_OF_LIBRARIES"
# echo "Total of $(echo -e $COMPLETE_LIST_OF_LIBRARIES | wc -w) libraries"
# echo " "

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "List of libraries already installed"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$COMPLETE_LIST_OF_LIBRARIES_YES"
# echo "Total of $(echo -e $COMPLETE_LIST_OF_LIBRARIES_YES | wc -w) libraries"
# echo " "

echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo "List of libraries that need to be installed"
echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo -e "$COMPLETE_LIST_OF_LIBRARIES_NO"
echo "Total of $(echo -e $COMPLETE_LIST_OF_LIBRARIES_NO | wc -w) libraries"
echo " "

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "Complete list of executables"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$COMPLETE_LIST_OF_EXECUTABLES"
# echo "Total of $(echo -e $COMPLETE_LIST_OF_EXECUTABLES | wc -w) executables"
# echo " "

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "Complete list of installed executables"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$COMPLETE_LIST_OF_EXECUTABLES_YES"
# echo "Total of $(echo -e $COMPLETE_LIST_OF_EXECUTABLES_YES | wc -w) executables"
# echo " "

echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo "Complete list of executables that need to be installed"
echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo -e "$COMPLETE_LIST_OF_EXECUTABLES_NO"
echo "Total of $(echo -e $COMPLETE_LIST_OF_EXECUTABLES_NO | wc -w) executables"
echo " "

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "Complete list of library functions"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$COMPLETE_LIST_OF_FUNCTIONS"
# echo "Total of $(echo -e $COMPLETE_LIST_OF_FUNCTIONS | wc -w) functions"
# echo " "

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "Complete list of installed library functions"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$COMPLETE_LIST_OF_FUNCTIONS_YES"
# echo "Total of $(echo -e $COMPLETE_LIST_OF_FUNCTIONS_YES | wc -w) functions"
# echo " "

echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo "Complete list of library functions that need to be installed"
echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo -e "$COMPLETE_LIST_OF_FUNCTIONS_NO"
echo "Total of $(echo -e $COMPLETE_LIST_OF_FUNCTIONS_NO | wc -w) functions"
echo " "

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "List of remaining unmatched 'checking for' lines"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$UNMATCHED_CHECKS"
# echo "END OF SECTION"

# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo "List of 'checking for' checks that matched but generated errors"
# echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
# echo -e "$ERROR_CHECKS"
# echo "END OF SECTION"