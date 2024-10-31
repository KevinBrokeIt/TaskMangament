#!/bin/bash
#Created by Evan Newman, CICS Umass, 10/31/2024
#This script was created as a way to help me track my daily tasks.
#Since I have a bunch of random task I needed a way to keep track of them.
#This app will help keep track of what you need to do so you don't have a million stickynotes


# Define paths to storage files and directories
TASKS_FILE="data/tasks.txt"
BACKBURNER_FILE="data/backburner.txt"
CONFIG_FILE="data/config.txt"
REPORTS_DIR="reports"
LOG_FILE="logs/error.log"

# Create necessary directories if they don't exist
mkdir -p "$(dirname "$TASKS_FILE")" "$(dirname "$BACKBURNER_FILE")" "$REPORTS_DIR" "$(dirname "$LOG_FILE")"

# View Today’s Tasks
view_tasks() {
    clear
    echo "Today's Tasks:"
    echo "-------------------------"

    # Check if there are any pending tasks
    if [[ ! -s "$TASKS_FILE" || $(grep -c 'Status:Pending' "$TASKS_FILE") -eq 0 ]]; then
        echo "No pending tasks for today."
    else
        local task_number=1
        while IFS='|' read -r task; do
            status=$(echo "$task" | awk -F 'Status:' '{print $2}' | awk -F '|' '{print $1}')
            if [[ "$status" == "Pending" ]]; then
                title=$(echo "$task" | awk -F 'Title:' '{print $2}' | awk -F '|' '{print $1}')
                echo "$task_number. $title"
                task_number=$((task_number + 1))
            fi
        done < "$TASKS_FILE"
    fi

    echo "-------------------------"
    echo "Options:"
    echo "1. Add a New Task"
    echo "2. Mark Task as Complete"
    echo "3. View Backburner"
    echo "4. Return to Main Menu"
    read -p "Choose an option: " choice

    case $choice in
        1) add_task ;;
        2) mark_task_complete ;;
        3) view_backburner ;;
        4) main_menu ;;
        *) echo "Invalid option. Returning to main menu." ; main_menu ;;
    esac
}

# View Completed Tasks
view_completed_tasks() {
    clear
    echo "Completed Tasks for Today:"
    echo "-------------------------"
    current_date=$(date +%Y-%m-%d)

    if grep -q "Status:Completed|Last Completed:$current_date" "$TASKS_FILE"; then
        grep "Status:Completed|Last Completed:$current_date" "$TASKS_FILE" | awk -F '|' '{print "- " $2}'
    else
        echo "No tasks completed today."
    fi
    read -p "Press Enter to return to the main menu..."
    main_menu
}

# Add a New Task
# Function to add a new task
add_task() {
    while true; do
        clear
        echo "Add a New Task"
        echo "========================="

        # Prompt for task title
        read -p "Task Title: " title

        # Prompt for frequency
        echo "Set Frequency:"
        echo "1. Daily"
        echo "2. Weekly"
        echo "3. Monthly"
        echo "4. One-Time"
        read -p "Choose an option (1-4): " frequency_choice

        case $frequency_choice in
            1) frequency="Daily" ;;
            2) frequency="Weekly" ;;
            3) frequency="Monthly" ;;
            4) frequency="One-Time" ;;
            *)
                echo "Invalid selection, please try again."
                read -p "Press Enter to continue..."
                continue
                ;;
        esac

        # Append task to the task file
       # echo "Title:$title|Frequency:$frequency|Status:Pending|Last Completed:N/A" >> "$TASKS_FILE"
       # echo "Task added."
        task_id=$(date +%s)  # Unique ID based on timestamp
        echo "ID:$task_id|Title:$title|Status:Pending|Frequency:$frequency|Last Completed:N/A" >> "$TASKS_FILE"
#        read -p "Press Enter to continue..."

        # Prompt to add another task or return to main menu
        read -p "Would you like to add another task? (Y/N): " choice
        if [[ "$choice" =~ ^[Nn]$ ]]; then
#            sleep 1
            view_tasks
           # return  # Exit to main menu
        fi
    done
}

# Mark Task as Complete
mark_task_complete() {
    clear
    echo "Mark a Task as Complete"
    echo "Please choose a task to mark as complete:"

    # Display pending tasks
    task_list=()
    task_number=1  # Initialize a counter for user-friendly numbering
    while IFS='|' read -r task; do
        status=$(echo "$task" | awk -F 'Status:' '{print $2}' | awk -F '|' '{print $1}')
        if [ "$status" == "Pending" ]; then
            title=$(echo "$task" | awk -F 'Title:' '{print $2}' | awk -F '|' '{print $1}')
            echo "$task_number. $title"  # Display friendly number and task title
            task_list+=("$task")  # Store the task for later processing
            ((task_number++))  # Increment the user-friendly task number
        fi
    done < "$TASKS_FILE"

    if [ ${#task_list[@]} -eq 0 ]; then
        echo "No pending tasks to mark as complete."
        read -p "Press Enter to continue..."
###EDITTTT
#	return
        view_tasks
#####
    fi

    read -p "Enter the task number or title to mark as complete: " input

    # Check if input is a number
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        task_index=$((input - 1))
        if [ "$task_index" -ge 0 ] && [ "$task_index" -lt "${#task_list[@]}" ]; then
            selected_task="${task_list[$task_index]}"
        else
            echo "Invalid task number."
            read -p "Press Enter to continue..."
            return
        fi
    else
        # If input is not a number, assume it's a title
        selected_task=$(echo "${task_list[@]}" | grep -i "$input" | head -n 1)
        if [ -z "$selected_task" ]; then
            echo "No task found with the title '$input'."
            read -p "Press Enter to continue..."
            return
        fi
    fi

    # Extract the task ID for updating
    id=$(echo "$selected_task" | awk -F 'ID:' '{print $2}' | awk -F '|' '{print $1}')
    current_date=$(date +%Y-%m-%d)

    # Mark the task as complete using sed
    sed -i "s/ID:$id|Title:\(.*\)|Status:Pending/ID:$id|Title:\1|Status:Completed|Last Completed:$current_date/" "$TASKS_FILE"
    echo "Task marked as complete."
#    read -p "Press Enter to continue..."
    view_tasks
}

# Reporting Functions

# View and print daily report
print_daily_report() {
    report_file="$REPORTS_DIR/daily_report_$(date +%Y-%m-%d).txt"
    {
        echo "Daily Report - $(date +%Y-%m-%d)"
        echo "=============================="
        if grep -q "Status:Completed|Last Completed:$(date +%Y-%m-%d)" "$TASKS_FILE"; then
            grep "Status:Completed|Last Completed:$(date +%Y-%m-%d)" "$TASKS_FILE" | awk -F '|' '{print "- " $2}'
        else
            echo "No tasks completed today."
        fi
    } > "$report_file"
    echo "Daily report generated: $report_file"
    read -p "Press Enter to continue..."
 reporting_menu
}

# View and print weekly report
print_weekly_report() {
    report_file="$REPORTS_DIR/weekly_report_$(date +%Y-%m-%d).txt"
    {
        echo "Weekly Report - $(date +%Y-%m-%d)"
        echo "=============================="
        grep "Status:Completed" "$TASKS_FILE" | awk -F '|' '{print "- " $2}'
    } > "$report_file"
    echo "Weekly report generated: $report_file"
    read -p "Press Enter to continue..."
 reporting_menu
}

# Print Today's Completed Tasks to Screen
print_daily_completed_tasks() {
    clear
    echo "Today's Completed Tasks:"
    echo "=============================="
    current_date=$(date +%Y-%m-%d)

    if grep -q "Status:Completed|Last Completed:$current_date" "$TASKS_FILE"; then
        grep "Status:Completed|Last Completed:$current_date" "$TASKS_FILE" | awk -F '|' '{print "- " $2}'
    else
        echo "No tasks completed today."
        sleep 3
        reporting_menu
    fi
    read -p "Press Enter to continue..."
        reporting_menu
}

# Print This Week's Completed Tasks to Screen
print_weekly_completed_tasks() {
    clear
    echo "This Week's Completed Tasks:"
    echo "=============================="
    start_of_week=$(date -d "last Sunday" +%Y-%m-%d)  # Get the start date of the current week
    end_of_week=$(date +%Y-%m-%d)  # Current date

    if grep -q "Status:Completed" "$TASKS_FILE"; then
        echo "Completed Tasks from $start_of_week to $end_of_week:"
        grep "Status:Completed" "$TASKS_FILE" | awk -F '|' '{print "- " $2}'
    else
        echo "No tasks completed this week."
        sleep 3
        reporting_menu
    fi
    read -p "Press Enter to continue..."
        reporting_menu
}


# Reporting Menu
reporting_menu() {
    clear
    echo "Reporting Menu"
    echo "=============================="
    echo "1. View Daily Report"
    echo "2. View Weekly Report"
    echo "3. Print Options"
    echo "4. Return to Main Menu"
    echo "=============================="
    read -p "Choose an option (1-4): " choice

    case $choice in
        1) print_daily_completed_tasks ;;
        2) print_weekly_completed_tasks ;;
        3) 
            echo "Options:"
            echo "1. Print Daily Report"
            echo "2. Print Weekly Report"
            read -p "Choose an option: " sub_choice
            case $sub_choice in
                1) print_daily_report ;;
                2) print_weekly_report ;;
                *) echo "Invalid option." ;;
            esac
            ;;
        4) main_menu ;;
        *) echo "Invalid option. Returning to main menu." ; main_menu ;;
    esac
}
# View Backburner Tasks
view_backburner() {
    clear
    echo "Backburner Tasks:"
    echo "-------------------------"
    if [ ! -s "$BACKBURNER_FILE" ]; then
        echo "No tasks in backburner."
    else
        cat "$BACKBURNER_FILE"
    fi
    read -p "Press Enter to return to the main menu..."
    main_menu
}

# Add to Backburner
add_to_backburner() {
    clear
    echo "Add a Task to Backburner"
    read -p "Task Title: " title
    echo "$title" >> "$BACKBURNER_FILE"
    echo "Task added to backburner."
    read -p "Press Enter to continue..."
}



# Main Menu
main_menu() {
    clear
    echo "=============================="
    echo "          Task Manager        "
    echo "=============================="
    echo "1. View Today's Tasks"
    echo "2. View Completed Tasks"
    echo "3. Add a New Task"
    echo "4. Mark a Task as Complete"
    echo "5. Reporting Menu"
    echo "6. Settings"
    echo "7. Exit"
    echo "=============================="
    read -p "Please choose an option (1-7): " choice

    case $choice in
        1) view_tasks ;;
        2) view_completed_tasks ;;
        3) add_task ;;
        4) mark_task_complete ;;
        5) reporting_menu ;;
        6) settings ;;
        7) exit 0 ;;
        *)
            echo "Invalid option, please try again."
            read -p "Press Enter to continue..."
            main_menu
            ;;
    esac
}

# Initialize Files if They Don’t Exist
initialize_files() {
    touch "$TASKS_FILE" "$BACKBURNER_FILE" "$CONFIG_FILE" "$LOG_FILE"
}
# Settings: Edit Configurations
settings() {
    nano "$CONFIG_FILE"
    main_menu
}


initialize_files
main_menu

