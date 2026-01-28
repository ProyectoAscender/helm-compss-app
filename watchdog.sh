#!/usr/bin/env bash
# watchdog.sh
# Ejecutar cada minuto en bucle

NAMESPACE="kafka"
CONTAINER="master"
REMOTE_HOST="192.168.88.249"
USER="${USER:-$(whoami)}"

while true; do
    echo "================ $(date) ================"
    echo "Monitorizando pods smartcity-compss en $NAMESPACE..."

    PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')

    for POD in $PODS; do
        case "$POD" in
            smartcity-compss-master-*)
                RELEASE="smartcity-compss"
                ;;
            smartcity-compss2-master-*)
                RELEASE="smartcity-compss2"
                ;;
            *)
                continue
                ;;
        esac

        echo "----------------------------------------"
        echo "Pod encontrado: $POD"
        echo "Release asociado: $RELEASE"

        BASE_NAME=$(echo "$POD" | sed 's/-[^-]*$//')
        echo "Nombre base: $BASE_NAME"

        echo "Comprobando logs recientes..."
        LOG_OUTPUT=$(kubectl logs -n "$NAMESPACE" "$POD" \
            -c "$CONTAINER" \
            --since=1s 2>/dev/null)

        if [ -z "$LOG_OUTPUT" ]; then
            echo "⚠️  No hay logs. Actuando para $RELEASE..."

            if [ "$RELEASE" = "smartcity-compss" ]; then
                echo "→ helm uninstall smartcity-compss"
                helm uninstall smartcity-compss -n "$NAMESPACE" 2>/dev/null
                sleep 30
                echo "→ helm install smartcity-compss"
                helm install -n "$NAMESPACE" smartcity-compss . --set username="$USER"

                echo "→ Ejecutando Docker en local"
                cd "/home/$USER/camera-edge" || exit 1
                docker stop edge_vmasip 2>/dev/null
                sleep 12
                bash docker/l4t-trt/runDocker.sh

            else
                echo "→ helm uninstall smartcity-compss2"
                helm uninstall smartcity-compss2 -n "$NAMESPACE" 2>/dev/null
                sleep 30
                echo "→ helm install smartcity-compss2"
                helm install -n "$NAMESPACE" smartcity-compss2 . --set username="$USER"

                echo "→ Ejecutando Docker en remoto ($REMOTE_HOST)"
                ssh "$USER@$REMOTE_HOST" "
                    cd /home/$USER/camera-edge &&
                    docker stop edge_vmasip 2>/dev/null &&
                    sleep 12 &&
                    bash docker/l4t-trt/runDocker.sh
                "
            fi

        else
            echo "✅ El proceso sigue activo."
        fi
    done

    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] Esperando 60 segundos antes del siguiente ciclo..."
    
    sleep 60
done
