#/bin/bash 

# (C) 2011 Henri Shustak
# Lucid Information Systems
# http://www.lucidsystems.org
# http://www.lucid.technology/tools/vmware/fusion-scripts

# Released under the GNU GPL v3 or later.

# Version history 
# v1.0 - initial release
# v1.1 - added optional reporting of VM's which are stoped by the script
# v1.2 - added support for VMWare Fusion 4 and later
# v1.3 - added additional reporting feature, including the ability generate a file containing a list of vm's which have been stoped.

# basic script which will attempt to stop all VMWare Fusion systems running on a system.

# configuration 

# if the environment variable 'list_stoped' is set to 'YES' then report the VM's which are stoped.
if [ "${list_stoped}" == "" ] ; then
    # when stoping VM's the default is to not report that they have been stoped.
    list_stoped="NO"
fi

# if the environment variable 'list_number_of_vms_stoped' is set to "YES" then report the number of VM's stoped
if [ "${list_number_of_vms_stoped}" == "" ] ; then
    # when stoping VM's the default is to not report how many have been stoped.
    list_number_of_vms_stoped="NO"
fi

# if the environment variable 'write_paths_for_stoped_vms_to_file' is set to "YES" then erase the file
# which is passed into this script as the first argument and then update this file with a list of the VM's
# that have been successfully stoped during the execution of this script.
if [ "${write_paths_for_stoped_vms_to_file}" == "" ] ; then
    # when stoping VM's the default is to not report how many have been stoped.
    write_paths_for_stoped_vms_to_file="NO"
fi


# internal variables
OLD_VMRUN_PATH="/Library/Application Support/VMware Fusion/vmrun"
VMRUN_PATH="/Applications/VMware Fusion.app/Contents/Library/vmrun"
num_vms_running=0
run_count_multiplier=2
run_count=0
max_run_count=0 
next_vm_to_stop=""
num_vms_succesfully_stoped=0
output_file_path_for_list_of_stoped_vms="${1}"

# out put file checks
if [ "${output_file_path_for_list_of_stoped_vms}" == "" ] && [ "${write_paths_for_stoped_vms_to_file}" == "YES" ] ; then
    write_paths_for_stoped_vms_to_file="NO"
    echo "    WARNING! : stoped VM's will not be written to disk as there was no output file provided."
fi
if [ "${write_paths_for_stoped_vms_to_file}" == "YES" ] ; then
    touch "${output_file_path_for_list_of_stoped_vms}"
    if [ $? != 0 ] || ! [ -w "${output_file_path_for_list_of_stoped_vms}" ] ; then
        echo "    WARNING! : stoped VM's will not be written to disk because the specified file was not able to be modified."
    fi
fi
if [ "${write_paths_for_stoped_vms_to_file}" != "YES" ] && [ "${output_file_path_for_list_of_stoped_vms}" != "" ] ; then
    echo "    WARNING! : The variable 'write_paths_for_stoped_vms_to_file' is not set to a value other than \"YES\""
    echo "               and an output file was specified was specified \(first argument passed to this script\)."
    echo "               Please note, that if the enviroment variable is set to \"YES\" and this script executed,"
    echo "               then the output (file specified as the first argument to this this script) will be deleted"
    echo "               should it exit at the path specified."
fi

# try using the old vmrun path should the current path not be available
if ! [ -e "${VMRUN_PATH}" ] ; then VMRUN_PATH="${OLD_VMRUN_PATH}" ; fi

# how many vms are running?
function calculate_num_vms_to_stop {
    sync
    num_vms_running=`"${VMRUN_PATH}" list | head -n 1 | awk -F "Total running VMs: " '{print $2}'`
    if [ $? != 0 ] || [ "$num_vms_running" == "" ] ; then
        # report the problem with getting the list of vm's
        echo "    ERROR! : Unable to determine the number of VM instances which are running : ${next_vm_to_stop}"
        sleep 3
        sync
        exit -1
    fi
}

# get path to the vm we will try to stop next
function calculate_path_to_next_vm_to_stop {
    next_vm_to_stop=`"${VMRUN_PATH}" list | head -n 2 | tail -n 1`
    if [ $? != 0 ] || [ "$num_vms_running" == "" ] ; then
        # report the problem with getting the list of vm's
        echo "    ERROR! : Unable to determine the path to the next VM instances to stop : ${next_vm_to_stop}"
        sleep 3
        sync
        exit -5
    fi
}

# stop next vm
function stop_next_vm {
    if [ "${next_vm_to_stop}" != "" ] ; then 
        sync
        stop_result=`"${VMRUN_PATH}" -T fusion stop "${next_vm_to_stop}"`
        if [ $? != 0 ] ; then
            # report the problem with stoping this VM
            echo "    ERROR! : Unable to stop VM : ${next_vm_to_stop}"
            sleep 3
            sync
        else
            ((num_vms_succesfully_stoped++))
            if [ "${list_stoped}" == "YES" ] ; then
                echo "    Successfully stoped VM : ${next_vm_to_stop}"
            fi
            if [ "${write_paths_for_stoped_vms_to_file}" == "YES" ] ; then
                echo "${next_vm_to_stop}" >> "${output_file_path_for_list_of_stoped_vms}"
                if [ $? != 0 ] ; then
                    echo "ERROR! : Unable to append this VM which has been stoped to the output file specified."
                    echo "             VM successfully stoped : ${next_vm_to_stop}"
                    echo "             Output file specified : ${output_file_path_for_list_of_stoped_vms}"
                fi
            fi
        fi
    else
        # this check is not essential as it is covered by another function
        calculate_num_vms_to_stop
        if [ ${num_vms_running} == 0 ] ; then
            echo "    ERROR! : No VM instances was found to stop."
            exit -3
        else
            echo "    ERROR! : VM instances was found to stop, but was not able to determine the path within the filesystem."
            exit -4
        fi
    fi
}

# logic
if [ -e "${VMRUN_PATH}" ] ; then
    calculate_num_vms_to_stop
    if [ "${write_paths_for_stoped_vms_to_file}" == "YES" ] ; then
        cat /dev/null > "${output_file_path_for_list_of_stoped_vms}"
    fi
    max_run_count=`echo "$num_vms_running * ${run_count_multiplier}" | bc`
    while [ $num_vms_running != 0 ] ; do
        # One or more VM's are running and will try attempt to stop.
        if [ ${run_count} != $max_run_count ] || [ $num_vms_running != 0 ] ; then
            # we have not hix the max run count
            calculate_path_to_next_vm_to_stop
            stop_next_vm
        else
          break  
        fi
        ((run_count++))
        calculate_num_vms_to_stop
    done
    if [ "${list_number_of_vms_stoped}" == "YES" ] ; then
        echo "    Total Number of VM's successfully stoped : ${num_vms_succesfully_stoped}"
    fi
else
    echo "    ERROR! : Unable to locate the VMWare Fusion run file."
    echo "             Please check that VMware Fusion is installed on this system."
    echo "             File referenced : ${VMRUN_PATH}"
    exit -2
fi



exit 0

