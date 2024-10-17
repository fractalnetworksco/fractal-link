#!/bin/sh

# This script sets up, removes, and shows port forwarding rules using nftables.

show_usage() {
    echo "Usage: $0 [-v] [add|remove|show] [tcp|udp] <listen_port> <target_ip> <target_port> [allowed_source] [local_interface_ip]"
    echo "Example: $0 add tcp 8000 192.168.0.1 80"
    echo "         $0 add udp 5353 10.0.0.53 53 203.0.113.0/24"
    echo "         $0 remove tcp 8000 192.168.0.1 80"
    echo "         $0 show"
}

check_nftables() {
    if ! nft list tables >/dev/null 2>&1; then
        echo "Error: nftables is not running or not initialized. Please ensure nftables is properly set up."
        exit 1
    fi
}

setup_nftables_structure() {
    # Create nat table if it doesn't exist
    if ! nft list table ip nat >/dev/null 2>&1; then
        nft add table ip nat || { echo "Failed to create nat table"; exit 1; }
    fi

    # Create and configure chains in nat table
    for chain in prerouting postrouting output; do
        if ! nft list chain ip nat $chain >/dev/null 2>&1; then
            nft add chain ip nat $chain { type nat hook $chain priority 0 \; } || { echo "Failed to create $chain chain"; exit 1; }
        fi
    done

    # Create filter table if it doesn't exist
    if ! nft list table ip filter >/dev/null 2>&1; then
        nft add table ip filter || { echo "Failed to create filter table"; exit 1; }
    fi

    # Create and configure forward chain in filter table
    if ! nft list chain ip filter forward >/dev/null 2>&1; then
        nft add chain ip filter forward { type filter hook forward priority 0 \; policy accept \; } || { echo "Failed to create forward chain"; exit 1; }
    fi
}

add_forward() {
    local proto=$1
    local listen_port=$2
    local target_ip=$3
    local target_port=$4
    local allowed_source=$5
    local container_ip=$6

    local src_rule=""
    local src_msg=""
    [ -n "$allowed_source" ] && {
        src_rule="ip saddr $allowed_source"
        src_msg=" (only from $allowed_source)"
    }

    log "Adding NAT prerouting rule..."
    nft add rule ip nat prerouting $src_rule $proto dport $listen_port dnat to $target_ip:$target_port || { echo "Failed to add prerouting rule"; return 1; }

    log "Adding NAT output rule..."
    nft add rule ip nat output $proto dport $listen_port ip daddr $container_ip dnat to $target_ip:$target_port || { echo "Failed to add output rule"; return 1; }

    log "Adding filter forward rule..."
    nft add rule ip filter forward $src_rule $proto dport $target_port ip daddr $target_ip ct state new accept || { echo "Failed to add forward rule"; return 1; }

    log "Adding NAT postrouting rule..."
    nft add rule ip nat postrouting ip daddr $target_ip $proto dport $target_port masquerade || { echo "Failed to add postrouting rule"; return 1; }

    echo "Added $proto forward: incoming on port $listen_port$src_msg will be sent to $target_ip:$target_port"
    echo "Container IP for local forwards: $container_ip"
}

remove_forward() {
    local proto=$1
    local listen_port=$2
    local target_ip=$3
    local target_port=$4
    local allowed_source=$5
    local container_ip=$6

    local src_rule=""
    local src_msg=""
    [ -n "$allowed_source" ] && {
        src_rule="ip saddr $allowed_source"
        src_msg=" (only from $allowed_source)"
    }

    log "Removing NAT prerouting rule..."
    rule_handle=$(nft -a list chain ip nat prerouting | grep "$src_rule $proto dport $listen_port.*dnat to $target_ip:$target_port" | awk '{print $NF}')
    if [ -n "$rule_handle" ]; then
        nft delete rule ip nat prerouting handle "$rule_handle" || echo "Error: Failed to delete prerouting rule."
    else
        echo "Error: No matching prerouting rule found."
    fi

    log "Removing NAT output rule..."
    rule_handle=$(nft -a list chain ip nat output | grep "$proto dport $listen_port ip daddr $container_ip.*dnat to $target_ip:$target_port" | awk '{print $NF}')
    if [ -n "$rule_handle" ]; then
        nft delete rule ip nat output handle "$rule_handle" || echo "Error: Failed to delete output rule."
    else
        echo "Error: No matching output rule found."
    fi

    log "Removing filter forward rule..."
    rule_handle=$(nft -a list chain ip filter forward | grep "$src_rule $proto dport $target_port ip daddr $target_ip ct state new accept" | awk '{print $NF}')
    if [ -n "$rule_handle" ]; then
        nft delete rule ip filter forward handle "$rule_handle" || echo "Error: Failed to delete forward rule."
    else
        echo "Error: No matching forward rule found."
    fi

    log "Removing NAT postrouting rule..."
    rule_handle=$(nft -a list chain ip nat postrouting | grep "ip daddr $target_ip $proto dport $target_port masquerade" | awk '{print $NF}')
    if [ -n "$rule_handle" ]; then
        nft delete rule ip nat postrouting handle "$rule_handle" || echo "Error: Failed to delete postrouting rule."
    else
        echo "Error: No matching postrouting rule found."
    fi

    echo "Removed $proto forward: incoming on port $listen_port$src_msg to $target_ip:$target_port"
}

show_forwards() {
    echo "Current Port Forwards:"
    echo "----------------------"

    echo "NAT Prerouting Rules:"
    nft list chain ip nat prerouting | grep dnat | sed 's/^[ \t]*/  /'

    echo "NAT Output Rules:"
    nft list chain ip nat output | grep dnat | sed 's/^[ \t]*/  /'

    echo "Forward Rules:"
    nft list chain ip filter forward | grep "dport .* ip daddr .* ct state new accept" | sed 's/^[ \t]*/  /'

    echo "NAT Postrouting Rules:"
    nft list chain ip nat postrouting | grep masquerade | sed 's/^[ \t]*/  /'
}

validate_port_number() {
    port=$1
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Error: Invalid port number $port. Must be an integer between 1 and 65535."
        exit 1
    fi
}

log() {
    [ "$VERBOSE" = true ] && echo "$@"
}

enable_ip_forwarding() {
    if [ "$(cat /proc/sys/net/ipv4/ip_forward)" -ne 1 ]; then
        if ! echo 1 > /proc/sys/net/ipv4/ip_forward; then
            echo "Error: Failed to enable IP forwarding."
            exit 1
        fi
        echo "IP forwarding enabled."
    else
        echo "IP forwarding is already enabled."
    fi
}

main() {
    VERBOSE=false
    [ "$1" = "-v" ] && VERBOSE=true && shift

    [ "$1" = "show" ] && {
        show_forwards
        exit 0
    }

    [ $# -lt 5 -o $# -gt 7 ] && {
        show_usage
        exit 1
    }

    check_nftables
    setup_nftables_structure

    local action=$1
    local proto=$2
    local listen_port=$3
    local target_ip=$4
    local target_port=$5
    local allowed_source=$6
    local default_ip=$(ip -4 addr show | grep inet | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n 1)
    local container_ip=${7:-$default_ip}

    validate_port_number "$listen_port"
    validate_port_number "$target_port"

    enable_ip_forwarding

    case $action in
        add)
            add_forward "$proto" "$listen_port" "$target_ip" "$target_port" "$allowed_source" "$container_ip"
            ;;
        remove)
            remove_forward "$proto" "$listen_port" "$target_ip" "$target_port" "$allowed_source" "$container_ip"
            ;;
        *)
            echo "Invalid action. Use 'add', 'remove', or 'show'."
            show_usage
            exit 1
            ;;
    esac
}

# Run the main function
main "$@"
