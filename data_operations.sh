#!/usr/bin/bash
# data_operations.sh

function insert_row {
    local dbName="$1"
    read -r -p "Enter Table Name: " tName

    if [[ ! -f "$DATA_PATH/$dbName/$tName" ]]; then
        echo "Error: Table not found."
        return
    fi

    # Read Metadata
    local meta=$(cat "$DATA_PATH/$dbName/.$tName.meta")
    local row=""
    
    # IFS Logic to split metadata by '|'
    # We save original IFS to restore it later
    local OIFS=$IFS
    IFS='|' read -ra COLS <<< "$meta"
    IFS=$OIFS

    for col in "${COLS[@]}"; do
        # Extract name, type, key using awk logic equivalent
        # col format: name:type:pk
        local cName=$(echo $col | awk -F: '{print $1}')
        local cType=$(echo $col | awk -F: '{print $2}')
        local cKey=$(echo $col | awk -F: '{print $3}')

        while true; do
            read -r -p "Enter value for $cName ($cType): " val

            # Validation 1: Not Empty
            if [[ -z "$val" ]]; then echo "Cannot be empty"; continue; fi
            
            # Validation 2: Type Check
            if [[ "$cType" == "int" ]]; then
                if [[ ! "$val" =~ ^[0-9]+$ ]]; then
                    echo "Error: Must be Integer"; continue
                fi
            fi

            # Validation 3: PK Check (Using AWK to check existing IDs)
            if [[ "$cKey" == "pk" ]]; then
                # Check if ID exists in file
                # awk -F"|" -v check="$val" '$1 == check {found=1} END {if (found) exit 1}'
                # If awk exits with 1, it was found
                if awk -F"|" -v check="$val" '$1 == check {exit 1}' "$DATA_PATH/$dbName/$tName"; then
                    # Awk returned 0 (not found)
                    : 
                else
                    # Awk returned 1 (found)
                    echo "Error: PK '$val' already exists."; continue
                fi
            fi
            
            break
        done
        
        if [[ -z "$row" ]]; then
            row="$val"
        else
            row="$row|$val"
        fi
    done

    echo "$row" >> "$DATA_PATH/$dbName/$tName"
    echo "Row Inserted Successfully."
}

function select_data {
    local dbName="$1"
    read -r -p "Enter Table Name: " tName
    
    if [[ ! -f "$DATA_PATH/$dbName/$tName" ]]; then
        echo "Table not found."
        return
    fi

    echo "1) Select All"
    echo "2) Select Row by ID (PK)"
    read -r -p "Choice: " choice

    if [[ "$choice" == "1" ]]; then
        echo "--- Data ---"
        # Print using awk, replacing separator with Tab for clean view
        awk 'BEGIN{FS="|"; OFS="\t"} {print $0}' "$DATA_PATH/$dbName/$tName"
    elif [[ "$choice" == "2" ]]; then
        read -r -p "Enter ID: " id
        # Select row where first column equals ID
        awk -F"|" -v id="$id" '$1 == id {print $0}' "$DATA_PATH/$dbName/$tName"
    else
        echo "Invalid Choice"
    fi
}

function delete_row {
    local dbName="$1"
    read -r -p "Enter Table Name: " tName
    read -r -p "Enter PK (ID) to Delete: " id
    
    local file="$DATA_PATH/$dbName/$tName"
    
    if [[ ! -f "$file" ]]; then echo "Table not found"; return; fi

    # Use AWK to filter out the line. 
    # Logic: Print lines where $1 is NOT equal to id
    awk -F"|" -v id="$id" '$1 != id {print $0}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    
    echo "Row Deleted (if it existed)."
}

function update_row {
    local dbName="$1"
    read -r -p "Enter Table Name: " tName
    read -r -p "Enter PK (ID) to Update: " id

    local file="$DATA_PATH/$dbName/$tName"
    
    # Check if ID exists using awk
    if awk -F"|" -v id="$id" '$1 == id {exit 0} END {exit 1}' "$file"; then
        echo "Row Found. Deleting old data..."
        
        # Delete old row
        awk -F"|" -v id="$id" '$1 != id {print $0}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
        
        echo "Please Insert New Data:"
        # Call insert function (reuses validation logic)
        insert_row "$dbName"
    else
        echo "Error: ID Not Found."
    fi
}