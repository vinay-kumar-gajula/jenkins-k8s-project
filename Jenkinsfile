stage('Deploy') {
    steps {
        script {

            try {

                sh '''
                    set -e

                    echo "=========================================="
                    echo "Applying Kubernetes manifests"
                    echo "=========================================="

                    kubectl apply \
                        -f k8s/app/

                    echo
                    echo "=========================================="
                    echo "Updating Web Application Image"
                    echo "=========================================="

                    kubectl set image \
                        deployment/${APP_NAME} \
                        nginx=${IMAGE} \
                        -n ${NAMESPACE}

                    echo
                    echo "Deployment image updated to:"
                    echo "${IMAGE}"
                '''

                sh '''
                    set -e

                    echo "=========================================="
                    echo "Waiting for Web Application Rollout"
                    echo "=========================================="

                    kubectl rollout status \
                        deployment/${APP_NAME} \
                        -n ${NAMESPACE} \
                        --timeout=120s

                    echo
                    echo "Web application rollout successful."
                '''

                sh '''
                    set -e

                    echo "=========================================="
                    echo "Verifying Deployed Image"
                    echo "=========================================="

                    ACTUAL_IMAGE=$(kubectl get deployment ${APP_NAME} \
                        -n ${NAMESPACE} \
                        -o jsonpath='{.spec.template.spec.containers[0].image}')

                    echo "Expected Image: ${IMAGE}"
                    echo "Actual Image  : ${ACTUAL_IMAGE}"

                    if [ "${ACTUAL_IMAGE}" != "${IMAGE}" ]; then
                        echo
                        echo "ERROR: Image verification failed."
                        echo "Expected: ${IMAGE}"
                        echo "Actual  : ${ACTUAL_IMAGE}"
                        exit 1
                    fi

                    echo
                    echo "Image verification successful."
                '''

            } catch (Exception e) {

                echo "=========================================="
                echo "DEPLOYMENT / VERIFICATION FAILED"
                echo "=========================================="

                sh '''
                    echo "=== Deployment Status ==="

                    kubectl get deployment ${APP_NAME} \
                        -n ${NAMESPACE} \
                        -o wide || true

                    echo
                    echo "=== Pods ==="

                    kubectl get pods \
                        -n ${NAMESPACE} \
                        -o wide || true

                    echo
                    echo "=== ReplicaSets ==="

                    kubectl get rs \
                        -n ${NAMESPACE} || true

                    echo
                    echo "=== Recent Events ==="

                    kubectl get events \
                        -n ${NAMESPACE} \
                        --sort-by=.lastTimestamp \
                        | tail -30 || true
                '''

                echo "=========================================="
                echo "Rolling back Web Application"
                echo "=========================================="

                sh '''
                    kubectl rollout undo \
                        deployment/${APP_NAME} \
                        -n ${NAMESPACE}
                '''

                sh '''
                    echo "=== Waiting for Rollback ==="

                    kubectl rollout status \
                        deployment/${APP_NAME} \
                        -n ${NAMESPACE} \
                        --timeout=120s
                '''

                echo "Rollback completed successfully."

                error(
                    "Deployment failed. Previous version has been restored."
                )
            }
        }
    }
}
