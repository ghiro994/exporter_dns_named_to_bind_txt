#!/bin/bash

# DNS server da verificare (opzionale, passato come parametro)
DNS_SERVER="$1"

OUTPUT_DIR="./dns_export_$(date +%Y%m%d)"
mkdir -p "$OUTPUT_DIR"

# Percorso corretto del file di configurazione
CONF_FILE="/etc/named.conf"

echo "--- Inizio esportazione zone DNS ---"
if [ -n "$DNS_SERVER" ]; then
    echo "Modalità: VERIFICA DNS con settorizzazione attive/inattive"
    echo "DNS Server di riferimento: $DNS_SERVER"
else
    echo "Modalità: ESPORTAZIONE SEMPLICE senza verifica DNS"
fi
echo ""

if [ ! -f "$CONF_FILE" ]; then
    echo "ERRORE: Il file $CONF_FILE non esiste."
    exit 1
fi

grep -E '^zone' "$CONF_FILE" | while read -r line; do
    ZONE_NAME=$(echo "$line" | cut -d '"' -f 2)
    ZONE_FILE=$(grep -A 5 "zone \"$ZONE_NAME\"" "$CONF_FILE" | grep "file" | awk -F'"' '{print $2}')

    if [ -n "$ZONE_FILE" ] && [ -f "$ZONE_FILE" ]; then
        # Estrai il TLD (dominio di primo livello)
        TLD=$(echo "$ZONE_NAME" | awk -F'.' '{print $NF}')
        
        # Se DNS_SERVER è specificato, verifica lo stato della zona
        if [ -n "$DNS_SERVER" ]; then
            echo "Verifica DNS per: $ZONE_NAME"
            dig_result=$(dig +short NS "$ZONE_NAME" @$DNS_SERVER 2>/dev/null | grep -i "$DNS_SERVER")
            
            if [ -n "$dig_result" ]; then
                STATUS="attive"
                echo "  -> ATTIVA e agganciata a $DNS_SERVER"
            else
                STATUS="inattive"
                echo "  -> NON agganciata a $DNS_SERVER"
            fi
            
            # Crea la directory per STATUS/TLD
            TLD_DIR="$OUTPUT_DIR/$STATUS/$TLD"
        else
            # Senza DNS_SERVER, esporta solo per TLD
            echo "Esportazione: $ZONE_NAME"
            TLD_DIR="$OUTPUT_DIR/$TLD"
        fi
        
        mkdir -p "$TLD_DIR"
        
        echo "Esportazione file: $ZONE_NAME da $ZONE_FILE"
        sudo named-compilezone -f text -F text -o "$TLD_DIR/${ZONE_NAME}.txt" "$ZONE_NAME" "$ZONE_FILE" > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo "SUCCESS: $ZONE_NAME"
        else
            echo "ERRORE ESPORTAZIONE: $ZONE_NAME"
        fi
    else
        echo "SALTATA: File non trovato o percorso vuoto per $ZONE_NAME"
    fi
done

echo ""
echo "--- Esportazione completata ---"
echo "I file sono stati salvati in: $OUTPUT_DIR"

# Calcola statistiche reali contando i file
if [ -n "$DNS_SERVER" ]; then
    count_attive=$(find "$OUTPUT_DIR/attive" -name "*.txt" 2>/dev/null | wc -l)
    count_inattive=$(find "$OUTPUT_DIR/inattive" -name "*.txt" 2>/dev/null | wc -l)
else
    count_totali=$(find "$OUTPUT_DIR" -name "*.txt" 2>/dev/null | wc -l)
fi

# Genera report finale
REPORT_FILE="$OUTPUT_DIR/report.txt"
echo "Generazione report: $REPORT_FILE"

{
    echo "============================================"
    echo "REPORT ESPORTAZIONE ZONE DNS"
    echo "============================================"
    echo ""
    echo "Data esportazione: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Directory output: $OUTPUT_DIR"
    echo ""
    
    if [ -n "$DNS_SERVER" ]; then
        echo "Modalità: VERIFICA DNS con settorizzazione"
        echo "DNS Server verificato: $DNS_SERVER"
        echo ""
        echo "STATISTICHE:"
        echo "  - Zone attive (agganciate a $DNS_SERVER): $count_attive"
        echo "  - Zone inattive (non agganciate): $count_inattive"
        echo "  - Totale zone esportate: $((count_attive + count_inattive))"
        echo ""
        echo "STRUTTURA DIRECTORY:"
        echo "  - attive/ (zone agganciate al DNS)"
        echo "  - inattive/ (zone non agganciate)"
        echo "    Suddivise per TLD: it, com, eu, org, etc."
    else
        echo "Modalità: ESPORTAZIONE SEMPLICE"
        echo ""
        echo "STATISTICHE:"
        echo "  - Totale zone esportate: $count_totali"
        echo ""
        echo "STRUTTURA DIRECTORY:"
        echo "  Suddivise per TLD: it, com, eu, org, etc."
    fi
    
    echo ""
    echo "============================================"
    echo "DETTAGLIO PER TLD"
    echo "============================================"
    echo ""
    
    # Conta file per TLD
    if [ -n "$DNS_SERVER" ]; then
        for status_dir in "$OUTPUT_DIR"/*/; do
            if [ -d "$status_dir" ]; then
                status_name=$(basename "$status_dir")
                echo "[$status_name]"
                for tld_dir in "$status_dir"*/; do
                    if [ -d "$tld_dir" ]; then
                        tld_name=$(basename "$tld_dir")
                        file_count=$(ls -1 "$tld_dir"*.txt 2>/dev/null | wc -l)
                        echo "  $tld_name: $file_count zone"
                    fi
                done
                echo ""
            fi
        done
    else
        for tld_dir in "$OUTPUT_DIR"*/; do
            if [ -d "$tld_dir" ]; then
                tld_name=$(basename "$tld_dir")
                file_count=$(ls -1 "$tld_dir"*.txt 2>/dev/null | wc -l)
                echo "  $tld_name: $file_count zone"
            fi
        done
    fi
    
    echo ""
    echo "============================================"
    echo "Fine report"
    echo "============================================"
} > "$REPORT_FILE"

# Mostra statistiche a video
echo ""
echo "Statistiche finali:"
if [ -n "$DNS_SERVER" ]; then
    echo "  - Zone attive (agganciate a $DNS_SERVER): $count_attive"
    echo "  - Zone inattive (non agganciate): $count_inattive"
    echo "  - Totale zone esportate: $((count_attive + count_inattive))"
else
    echo "  - Totale zone esportate: $count_totali"
fi

echo ""
echo "Report salvato in: $REPORT_FILE"
