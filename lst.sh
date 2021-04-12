#!/bin/bash

help() {
	cat <<- eof
Usage: $(basename ${BASH_SOURCE[0]}) -client-hosts "HOST1 [HOST2]" -client-lnd-id "ID" -server-hosts "HOST1 [HOST2]" -server-lnd-id "ID"

Mandatory Options:
  -client-hosts "HOST1 [HOST2]"   Space-Separated List of Hostnames or IP Addresses for Clients
  -client-lnd-id ID               Lustre Network Driver (LND) ID for Clients: { o2ib<INSTANCE> | tcp<INSTANCE> }
  -server-hosts "HOST1 [HOST2]"   Space-Separated List of Hostnames or IP Addresses for Servers
  -server-lnd-id ID               Lustre Network Driver (LND) ID for Servers: { o2ib<INSTANCE> | tcp<INSTANCE> }

Additional Options #1 [LNET Selftest Execution Settings]:
  -concurrency CONCURRENCY         Concurrency                                                            Default: [32]
  -distribute DISTRIBUTE           Distribution: { 1:1 | 1:n | n:1 | n:n }                                Default: [1:1]
  -loop LOOP                       Number of Loops                                                        Default: [1]
  -mode MODE                       Mode: { read | write }                                                 Default: [Write]

Additional Options #2:
  -manage-lst-module-on-clients    Automatically Start/Stop LNET Selftest Module on Clients: { 0 | 1 }    Default: [0]
  -manage-lst-module-on-servers    Automatically Start/Stop LNET Selftest Module on Servers: { 0 | 1 }    Default: [0]
  -runtime                         Target Test Duration in Seconds                                        Default: [30]

Purpose:
  Runs LNET Selftest Read or Write Performance Test between Clients and Servers

eof

	exit 0
}

cleanup() {
	# End LST Session
	if lst show_session; then
		printf "[%s] Stopping LST Session: [%s]\n" "INFO" "lst-${LST_SESSION}"
		lst end_session
	fi
	# Unload LST Module
	if (( manage_lst_module_on_servers == 1 )); then
		for host in "${server_hosts[@]}"; do
			ssh -o "StrictHostKeyChecking=no" ${host} "modprobe -r lnet_selftest" || { printf "[%s] Failed to Unload LST Module on Server: [%s]\n" "ERROR" "${host}"; exit 1; }
		done
	fi
	if (( manage_lst_module_on_clients == 1 )); then
		for host in "${client_hosts[@]}"; do
			ssh -o "StrictHostKeyChecking=no" ${host} "modprobe -r lnet_selftest" || { printf "[%s] Failed to Unload LST Module on Client: [%s]\n" "ERROR" "${host}"; exit 1; }
		done
	fi

	return 0
}

while (( ${#} > 0 )); do
	case "${1}" in
		-client-hosts)
			IFS=" " read -a client_hosts <<<"${2}"
			shift
			;;
		-client-lnd-id)
			client_lnd_id="${2}"
			shift
			;;
		-concurrency)
			concurrency="${2}"
			shift
			;;
		-distribute)
			distribute="${2}"
			shift
			;;
		-help|-h)
			help
			;;
		-loop)
			loop="${2}"
			shift
			;;
		-manage-lst-module-on-clients)
			manage_lst_module_on_clients="${2}"
			shift
			;;
		-manage-lst-module-on-servers)
			manage_lst_module_on_servers="${2}"
			shift
			;;
		-mode)
			mode="${2}"
			shift
			;;
		-runtime)
			runtime="${2}"
			shift
			;;
		-server-hosts)
			IFS=" " read -a server_hosts <<<"${2}"
			shift
			;;
		-server-lnd-id)
			server_lnd_id="${2}"
			shift
			;;
		-size)
			size="${2}"
			shift
			;;
	esac
	shift
done
if (( ${#client_hosts[@]} == 0 )); then
	printf "[%s] Missing Argument: [%s]\n" "ERROR" "Client Hosts"
	exit 1
fi
if [[ -z "${client_lnd_id}" ]]; then
	printf "[%s] Missing Argument: [%s]\n" "ERROR" "Client LND ID"
	exit 1
fi
concurrency="${concurrency:-32}"
distribute="${distribute:-1:1}"
manage_lst_module_on_clients="${manage_lst_module_on_clients:-0}"
if (( manage_lst_module_on_clients != 0 )) && (( manage_lst_module_on_clients != 1)); then
	printf "[%s] Invalid Argument: [%s]\n" "ERROR" "Manage LST Module on CLients"
fi
manage_lst_module_on_servers="${manage_lst_module_on_clients:-0}"
if (( manage_lst_module_on_servers != 0 )) && (( manage_lst_module_on_servers != 1)); then
	printf "[%s] Invalid Argument: [%s]\n" "ERROR" "Manage LST Module on Servers]"
fi
mode="${mode:-write}"
if [[ "${mode}" != "read" ]] && [[ "${mode}" != "write" ]]; then
	printf "[%s] Invalid Mode: [%s]\n" "ERROR" "${mode}"
	exit 1
fi
runtime="${runtime:-30}"
if (( ${#server_hosts[@]} == 0 )); then
	printf "[%s] Missing Argument: [%s]\n" "ERROR" "Server Hosts"
	exit 1
fi
if [[ -z "${server_lnd_id}" ]]; then
	printf "[%s] Missing Argument: [%s]\n" "ERROR" "Server LND ID"
	exit 1
fi
size="${size:-1M}"

# Console
modprobe lnet_selftest || { printf "[%s] Failed to Load Module: [%s]\n" "ERROR" "lnet_selftest"; exit 1; }

# Servers
for (( index = 0; index < ${#server_hosts[@]}; ++index )); do
	host="${server_hosts[${index}]}"
	if ! [[ "${host}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		ip="$(host "${host}" 2>&1 | awk 'match($0, /^.*\s*has address\s*([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$/, a) {printf "%s", a[1]}')"
		if [[ "${ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
			printf "Translated Server Hostname: [%s] into IP Address: [%s]\n" "${host}" "${ip}"
		else
			printf "[%s] Failed to Translate Server Hostname: [%s] to IP Address\n" "ERROR" "${host}"
			exit 1
		fi
		nid="${ip}@${server_lnd_id}"
	else
		nid="${host}@${server_lnd_id}"
	fi
	if (( manage_lst_module_on_servers == 1 )); then
		printf "[%s] Attempting to Load LST Module on Server: [%s]\n" "INFO" "${host}"
		ssh -o "StrictHostKeyChecking=no" ${host} "modprobe lnet_selftest" || { printf "[%s] Failed to Load LST Module on Server: [%s]\n" "ERROR" "${host}"; exit 1; }
	fi
	if ! lnetctl ping "${nid}" &>/dev/null; then
		printf "[%s] Server NID Not Reachable through LNET Ping: [%s]\n" "ERROR" "${nid}"
		exit 1
	fi
	server_nids[${index}]="${nid}"
done

# Clients
for (( index = 0; index < ${#client_hosts[@]}; ++index )); do
	host="${client_hosts[${index}]}"
	if ! [[ "${host}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		ip="$(host "${host}" 2>&1 | awk 'match($0, /^.*\s*has address\s*([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$/, a) {printf "%s", a[1]}')"
		if [[ "${ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
			printf "Translated Server Hostname: [%s] into IP Address: [%s]\n" "${host}" "${ip}"
		else
			printf "[%s] Failed to Translate Server Hostname: [%s] to IP Address\n" "ERROR" "${host}"
			exit 1
		fi
		nid="${ip}@${client_lnd_id}"
	else
		nid="${host}@${client_lnd_id}"
	fi
	if (( manage_lst_module_on_clients == 1 )); then
		printf "[%s] Attempting to Load LST Module on Client: [%s]\n" "INFO" "${host}"
		ssh -o "StrictHostKeyChecking=no" ${host} "modprobe lnet_selftest" || { printf "[%s] Failed to Load LST Module on Client: [%s]\n" "ERROR" "${host}"; exit 1; }
	fi
	if ! lnetctl ping "${nid}" &>/dev/null; then
		printf "[%s] Client NID Not Reachable through LNET Ping: [%s]\n" "ERROR" "${nid}"
		exit 1
	fi
	client_nids[${index}]="${nid}"
done

trap "cleanup" EXIT SIGINT SIGTERM

# LST Session
export LST_SESSION="$$"
printf "LST Session ID: [%s]" "${LST_SESSION}"
lst new_session --force lst-${LST_SESSION} || { printf "[%s] Failed Creating LST Session: [%s]\n" "ERROR" "lst-${LST_SESSION}"; exit 1; }
# LST Groups
lst add_group servers "${server_nids[@]}" || { printf "[%s] Failed to Add LST Group: [%s]\n" "ERROR" "Servers"; exit 1; }
lst list_group servers --all
lst add_group clients "${client_nids[@]}" || { printf "[%s] Failed to Add LST Group: [%s]\n" "ERROR" "Clients"; exit 1; }
lst list_group clients --all
# LST Batch
batch="batch-${LST_SESSION}"
lst add_batch "${batch}"
# LST Test
#command="lst add_test --batch batch-${LST_SESSION} --concurrency ${concurrency} --distribute ${distribute} --from clients --loop ${loop} --to servers brw ${mode} size=${size}"
command="lst add_test --batch batch-${LST_SESSION} --concurrency ${concurrency} --distribute ${distribute} --from clients --to servers brw ${mode} size=${size}"
printf "Command: [%s]\n" "${command}"
${command} || { printf "Failed to Add LST Test\n"; exit 1; }
# LST Run
lst run "${batch}"
#(lst stat servers | awk -v mode=${mode} -v server=${server} -v client=${client} -v ooo=${relaxed_packet_ordering} 'BEGIN {read=0; readc=0; write=0; wrtiec=0}; /MiB/ && /[R]/ { readc+=1; read+=$3 } /MiB/ && /[W]/ { writec+=1; write+=$3} END { print("result,"server","client","ooo","mode","write/writec","read/readc) }') &
(lst stat clients) &
sleep "${runtime}"
killall lst
lst stop "${batch}"
lst end_session

exit 0
