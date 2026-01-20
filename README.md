# Documentazione Script export_zone.sh

## Descrizione

Script Bash per l'esportazione automatica delle zone DNS configurate in BIND (named). Lo script legge la configurazione da `/etc/named.conf`, esporta ogni zona in formato testo e organizza i file in una struttura gerarchica basata sul TLD (Top Level Domain).

## Caratteristiche Principali

- **Due modalità operative**: esportazione semplice o con verifica DNS
- **Organizzazione per TLD**: i file sono automaticamente suddivisi per estensione (it, com, eu, org, etc.)
- **Verifica DNS opzionale**: controllo dello stato delle zone su un nameserver specifico
- **Report automatico**: generazione di statistiche dettagliate
- **Naming consistente**: file organizzati in modo logico e facilmente navigabile

## Utilizzo

### Sintassi

```bash
./export_zone.sh [dns_server]
```

### Parametri

- `dns_server` (opzionale): Nome del server DNS da verificare per la settorizzazione delle zone

### Esempi

**Esportazione semplice (senza verifica DNS):**
```bash
./export_zone.sh
```

**Esportazione con verifica DNS:**
```bash
./export_zone.sh dns1.evoluzioniweb.it
```

## Modalità Operative

### Modalità 1: ESPORTAZIONE SEMPLICE

Attivata quando lo script viene eseguito **senza parametri**.

**Funzionamento:**
- Legge tutte le zone da `/etc/named.conf`
- Esporta ogni zona in formato testo
- Organizza i file per TLD

**Struttura output:**
```
dns_export_20260120/
├── it/
│   ├── dominio1.it.txt
│   ├── dominio2.it.txt
│   └── dominio3.it.txt
├── com/
│   ├── dominio1.com.txt
│   └── dominio2.com.txt
├── eu/
│   └── dominio1.eu.txt
└── report.txt
```

### Modalità 2: VERIFICA DNS CON SETTORIZZAZIONE

Attivata quando lo script viene eseguito **con il parametro DNS server**.

**Funzionamento:**
- Legge tutte le zone da `/etc/named.conf`
- Per ogni zona, esegue una query DNS verso il server specificato
- Verifica se il server è tra i nameserver della zona
- Classifica la zona come "attiva" o "inattiva"
- Esporta i file organizzandoli per stato e TLD

**Comando di verifica eseguito:**
```bash
dig +short NS dominio.it @dns1.evoluzioniweb.it | grep -i "dns1.evoluzioniweb.it"
```

**Struttura output:**
```
dns_export_20260120/
├── attive/
│   ├── it/
│   │   ├── dominio1.it.txt
│   │   └── dominio2.it.txt
│   ├── com/
│   │   └── dominio1.com.txt
│   └── eu/
│       └── dominio1.eu.txt
├── inattive/
│   ├── it/
│   │   └── dominio3.it.txt
│   └── com/
│       └── dominio2.com.txt
└── report.txt
```

## Processo di Esportazione

### 1. Lettura Configurazione

Lo script analizza `/etc/named.conf` cercando tutte le dichiarazioni di zona:

```bash
grep -E '^zone' "$CONF_FILE"
```

### 2. Estrazione Informazioni

Per ogni zona identificata, estrae:
- **Nome della zona**: estratto dalla dichiarazione `zone "nome.dominio"`
- **File della zona**: percorso del file di configurazione
- **TLD**: estensione del dominio (it, com, eu, etc.)

### 3. Verifica DNS (solo in modalità 2)

Se specificato un DNS server, per ogni zona:
1. Interroga il server DNS specificato per ottenere i nameserver
2. Verifica se il server specificato è presente nei nameserver
3. Classifica la zona come "attiva" o "inattiva"

### 4. Esportazione File

Utilizza il comando `named-compilezone` per esportare la zona:

```bash
sudo named-compilezone -f text -F text -o "percorso/output.txt" "nome.zona" "file.zona"
```

**Parametri:**
- `-f text`: formato input (testo)
- `-F text`: formato output (testo)
- `-o`: percorso file di output

### 5. Generazione Report

Al termine dell'esportazione, genera un file `report.txt` contenente:
- Data e ora dell'esportazione
- Modalità utilizzata
- Statistiche numeriche
- Dettaglio per TLD

## File di Output

### File delle Zone

Ogni zona viene esportata in un file `.txt` contenente:
- Record SOA (Start of Authority)
- Record NS (Nameserver)
- Record A, AAAA (indirizzi IP)
- Record MX (mail server)
- Record CNAME (alias)
- Record TXT
- Altri record DNS presenti

**Esempio di contenuto:**
```
dominio.it.              3600    IN    SOA    dns1.evoluzioniweb.it. postmaster.evoluzioniweb.it. (
                                       2024010101 ; serial
                                       86400      ; refresh
                                       3600       ; retry
                                       2592000    ; expire
                                       86400      ; default_ttl
                                       )
dominio.it.              3600    IN    NS     dns1.evoluzioniweb.it.
dominio.it.              3600    IN    NS     dns2.evoluzioniweb.it.
dominio.it.              3600    IN    A      192.168.1.1
www.dominio.it.          3600    IN    CNAME  dominio.it.
```

### Report.txt

File di riepilogo con statistiche complete:

**Sezioni del report:**
1. **Header**: data, directory output, modalità
2. **Statistiche**: conteggio zone per categoria
3. **Struttura directory**: organizzazione dei file
4. **Dettaglio per TLD**: conteggio zone per ogni estensione

## Requisiti

### Software Necessario

- **bash**: shell script
- **bind-utils**: comandi `dig` e `named-compilezone`
- **sudo**: permessi elevati per `named-compilezone`
- **find, grep, awk, cut**: utility standard Unix/Linux

### Permessi

Lo script necessita di:
- Lettura di `/etc/named.conf`
- Lettura dei file di zona in `/etc/named/`
- Esecuzione di `named-compilezone` con sudo
- Scrittura nella directory corrente per l'output

## Output del Terminale

### Durante l'esecuzione

Lo script mostra in tempo reale:
- Modalità operativa
- Nome della zona in elaborazione
- Stato della verifica DNS (se attiva)
- Successo o errore dell'esportazione

**Esempio di output:**
```
--- Inizio esportazione zone DNS ---
Modalità: VERIFICA DNS con settorizzazione attive/inattive
DNS Server di riferimento: dns1.evoluzioniweb.it

Verifica DNS per: dominio1.it
  -> ATTIVA e agganciata a dns1.evoluzioniweb.it
Esportazione file: dominio1.it da /etc/named/db.dominio1.it
SUCCESS: dominio1.it

Verifica DNS per: dominio2.com
  -> NON agganciata a dns1.evoluzioniweb.it
Esportazione file: dominio2.com da /etc/named/db.dominio2.com
SUCCESS: dominio2.com

--- Esportazione completata ---
I file sono stati salvati in: ./dns_export_20260120
Generazione report: ./dns_export_20260120/report.txt

Statistiche finali:
  - Zone attive (agganciate a dns1.evoluzioniweb.it): 150
  - Zone inattive (non agganciate): 25
  - Totale zone esportate: 175

Report salvato in: ./dns_export_20260120/report.txt
```

## Note Tecniche

### Gestione TLD

L'estrazione del TLD utilizza `awk`:
```bash
TLD=$(echo "$ZONE_NAME" | awk -F'.' '{print $NF}')
```

Questo comando:
- Divide il nome del dominio usando il punto come separatore
- Restituisce l'ultimo campo (NF = Number of Fields)

**Esempi:**
- `dominio.it` → `it`
- `esempio.com` → `com`
- `test.co.uk` → `uk`

### Conteggio Statistiche

Le statistiche vengono calcolate al termine dell'esportazione contando i file effettivamente creati:

```bash
count_attive=$(find "$OUTPUT_DIR/attive" -name "*.txt" 2>/dev/null | wc -l)
count_inattive=$(find "$OUTPUT_DIR/inattive" -name "*.txt" 2>/dev/null | wc -l)
```

Questo approccio garantisce che i numeri siano sempre accurati, anche in caso di errori durante l'esportazione.

### Zone Saltate

Uno zona viene saltata se:
- Il file della zona non esiste
- Il percorso del file è vuoto nella configurazione
- Non ci sono permessi di lettura sul file

### Naming delle Directory

Il formato della directory principale è:
```
dns_export_YYYYMMDD
```

Dove:
- `YYYY`: anno (4 cifre)
- `MM`: mese (2 cifre)
- `DD`: giorno (2 cifre)

**Esempio:** `dns_export_20260120` per il 20 gennaio 2026

## Troubleshooting

### Errore: "named-compilezone: command not found"

**Soluzione:** Installare bind-utils
```bash
# CentOS/RHEL
sudo yum install bind-utils

# Debian/Ubuntu
sudo apt-get install bind9utils
```

### Errore: "Permission denied" su /etc/named.conf

**Soluzione:** Eseguire con sudo o verificare i permessi del file

### Tutte le zone risultano "inattive"

**Possibili cause:**
- Il DNS server specificato non è raggiungibile
- Il DNS server specificato non è autoritative per quelle zone
- Problema di rete o firewall

**Verifica manuale:**
```bash
dig +short NS dominio.it @dns_server
```

### Mancano alcune zone nell'esportazione

**Verifica:**
1. Controllare se la zona è presente in `/etc/named.conf`
2. Verificare che il file della zona esista
3. Controllare i permessi del file della zona
4. Controllare il log a video per messaggi "SALTATA"

## Versione e Compatibilità

- **Shell:** Bash 4.0+
- **SO:** Linux (testato su CentOS/RHEL 7+)
- **BIND:** Versione 9.x

## Autore e Licenza

Script sviluppato per la gestione e backup delle zone DNS BIND.

## Changelog

- **v1.0**: Versione iniziale con esportazione base
- **v2.0**: Aggiunta verifica DNS e settorizzazione
- **v3.0**: Aggiunta organizzazione per TLD
- **v4.0**: Aggiunto report automatico con statistiche dettagliate
