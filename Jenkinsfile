pipeline {

    agent any

    environment {
        APP_NAME     = "web-app"
        CONTAINER_NAME = "nginx"
        NAMESPACE    = "devops"
        KIND_CLUSTER = "devops-lab"
        KUBECONFIG   = "/var/jenkins_home/kubeconfig"
    }

    stages {

        // ============================================================
        // Stage 1: Download source code from GitHub
        // ============================================================
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // ============================================================
        // Stage 2: Prepare build variables and verify required tools
        // ============================================================
        stage('Prepare') {
            steps {

                sh '''
                    set -e

                    echo "=========================================="
                    echo "Git Commit"
                    echo "=========================================="

                    git log --oneline -1

                    echo
                    echo "=========================================="
                    echo "Installed Tools"
                    echo "=========================================="

                    docker --version
                    kubectl version --client
                    kind version

                    echo
                    echo "=========================================="
                    echo "Kubernetes Nodes"
                    echo "=========================================="

                    kubectl get nodes
                '''

                script {
                    // Get the first seven characters of the Git commit ID.
                    env.GIT_SHA = sh(
                        script: 'git rev-parse --short=7 HEAD',
                        returnStdout: true
                    ).trim()

                    // Example: web-app:81e279d
                    env.IMAGE = "${env.APP_NAME}:${env.GIT_SHA}"

                    echo "Git SHA       : ${env.GIT_SHA}"
                    echo "Image to build: ${env.IMAGE}"
                }
            }
        }

        // ============================================================
        // Stage 3: Validate Kubernetes YAML files
        // ============================================================
        stage('Validate Manifests') {
            steps {
                sh '''
                    set -e

                    echo "=========================================="
                    echo "Validating Kubernetes Manifests"
                    echo "=========================================="

                    kubectl apply \
                        --dry-run=server \
                        -f k8s/app/

                    echo
                    echo "Manifest validation successful."
                '''
            }
        }

        // ============================================================
        // Stage 4: Build Docker image using the Git SHA
        // ============================================================
        stage('Build Docker Image') {
            steps {
                sh '''
                    set -e

                    echo "=========================================="
                    echo "Building Docker Image"
                    echo "=========================================="

                    echo "Image: ${IMAGE}"

                    docker build \
                        --tag "${IMAGE}" \
                        .

                    echo
                    echo "Docker image built successfully."

                    docker images "${APP_NAME}"
                '''
            }
        }

        // ============================================================
        // Stage 5: Load the locally built image into every kind node
        // ============================================================
        stage('Load Image into Kind') {
            steps {
                sh '''
                    set -e

                    echo "=========================================="
                    echo "Loading Image into Kind"
                    echo "=========================================="

                    echo "Cluster: ${KIND_CLUSTER}"
                    echo "Image  : ${IMAGE}"

                    kind load docker-image \
                        "${IMAGE}" \
                        --name "${KIND_CLUSTER}"

                    echo
                    echo "Image successfully loaded into Kind."
                '''
            }
        }

        // ============================================================
        // Stage 6: Deploy, verify rollout and rollback upon failure
        // ============================================================
        stage('Deploy') {
            steps {
                script {

                    /*
                     * Store the currently running image before applying
                     * any Kubernetes changes.
                     *
                     * Example:
                     * previousImage = web-app:abc1234
                     */
                    def previousImage = ""

                    /*
                     * This becomes true only when the pipeline starts
                     * updating the Deployment image.
                     */
                    def imageUpdateStarted = false

                    try {

                        // ------------------------------------------------
                        // Find the currently deployed stable image
                        // ------------------------------------------------
                        previousImage = sh(
                            script: """
                                kubectl get deployment ${APP_NAME} \
                                    --namespace ${NAMESPACE} \
                                    --output jsonpath='{.spec.template.spec.containers[?(@.name=="${CONTAINER_NAME}")].image}' \
                                    2>/dev/null || true
                            """,
                            returnStdout: true
                        ).trim()

                        echo "=========================================="
                        echo "Deployment Images"
                        echo "=========================================="

                        echo "Previous image: ${previousImage ?: 'Not available'}"
                        echo "New image     : ${env.IMAGE}"

                        // ------------------------------------------------
                        // Apply Kubernetes manifests
                        // ------------------------------------------------
                        sh '''
                            set -e

                            echo "=========================================="
                            echo "Applying Kubernetes Manifests"
                            echo "=========================================="

                            kubectl apply \
                                -f k8s/app/

                            echo
                            echo "Kubernetes manifests applied successfully."
                        '''

                        // The image-update operation is about to begin.
                        imageUpdateStarted = true

                        // ------------------------------------------------
                        // Update the web-app container image
                        // ------------------------------------------------
                        sh '''
                            set -e

                            echo "=========================================="
                            echo "Updating Web Application Image"
                            echo "=========================================="

                            kubectl set image \
                                deployment/${APP_NAME} \
                                ${CONTAINER_NAME}=${IMAGE} \
                                --namespace ${NAMESPACE}

                            echo
                            echo "Deployment image updated to ${IMAGE}."
                        '''

                        // ------------------------------------------------
                        // Wait for the new pods to become Ready
                        // ------------------------------------------------
                        sh '''
                            set -e

                            echo "=========================================="
                            echo "Waiting for Web Application Rollout"
                            echo "=========================================="

                            kubectl rollout status \
                                deployment/${APP_NAME} \
                                --namespace ${NAMESPACE} \
                                --timeout=120s

                            echo
                            echo "Web application rollout successful."
                        '''

                        // ------------------------------------------------
                        // Verify that the expected image was deployed
                        // ------------------------------------------------
                        sh '''
                            set -e

                            echo "=========================================="
                            echo "Verifying Deployed Image"
                            echo "=========================================="

                            ACTUAL_IMAGE=$(kubectl get deployment ${APP_NAME} \
                                --namespace ${NAMESPACE} \
                                --output jsonpath='{.spec.template.spec.containers[?(@.name=="'${CONTAINER_NAME}'")].image}')

                            echo "Expected image: ${IMAGE}"
                            echo "Actual image  : ${ACTUAL_IMAGE}"

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

                    } catch (Exception deploymentError) {

                        echo "=========================================="
                        echo "DEPLOYMENT FAILED"
                        echo "=========================================="

                        echo "Collecting Kubernetes diagnostics..."

                        // ------------------------------------------------
                        // Gather information before performing rollback
                        // ------------------------------------------------
                        sh '''
                            echo
                            echo "=== Deployment ==="

                            kubectl get deployment ${APP_NAME} \
                                --namespace ${NAMESPACE} \
                                --output wide || true

                            echo
                            echo "=== Pods ==="

                            kubectl get pods \
                                --namespace ${NAMESPACE} \
                                --output wide || true

                            echo
                            echo "=== ReplicaSets ==="

                            kubectl get replicasets \
                                --namespace ${NAMESPACE} \
                                --selector app=${APP_NAME} || true

                            echo
                            echo "=== Recent Events ==="

                            kubectl get events \
                                --namespace ${NAMESPACE} \
                                --sort-by=.metadata.creationTimestamp \
                                | tail -30 || true

                            echo
                            echo "=== Pod Descriptions ==="

                            kubectl describe pods \
                                --namespace ${NAMESPACE} \
                                --selector app=${APP_NAME} || true
                        '''

                        /*
                         * Roll back only when:
                         *
                         * 1. The image update was started.
                         * 2. A previous image was found.
                         */
                        if (imageUpdateStarted && previousImage) {

                            echo "=========================================="
                            echo "RESTORING PREVIOUS IMAGE"
                            echo "=========================================="

                            echo "Failed image  : ${env.IMAGE}"
                            echo "Restoring image: ${previousImage}"

                            /*
                             * Make the Groovy previousImage variable
                             * available inside the shell block.
                             */
                            withEnv(["PREVIOUS_IMAGE=${previousImage}"]) {

                                sh '''
                                    set -e

                                    kubectl set image \
                                        deployment/${APP_NAME} \
                                        ${CONTAINER_NAME}=${PREVIOUS_IMAGE} \
                                        --namespace ${NAMESPACE}

                                    echo
                                    echo "Waiting for rollback to complete..."

                                    kubectl rollout status \
                                        deployment/${APP_NAME} \
                                        --namespace ${NAMESPACE} \
                                        --timeout=120s
                                '''
                            }

                            echo "Rollback completed successfully."

                            error(
                                "Deployment of ${env.IMAGE} failed. " +
                                "Previous image ${previousImage} was restored."
                            )
                        }

                        /*
                         * This happens if manifest application failed
                         * before the image update started, or if this
                         * is the first deployment and no old image exists.
                         */
                        error(
                            "Deployment failed, but no previous application " +
                            "image was available for rollback. " +
                            "Original error: ${deploymentError.getMessage()}"
                        )
                    }
                }
            }
        }

        // ============================================================
        // Stage 7: Display final Kubernetes deployment information
        // ============================================================
        stage('Verify Deployment') {
            steps {
                sh '''
                    set -e

                    echo "=========================================="
                    echo "Pods"
                    echo "=========================================="

                    kubectl get pods \
                        --namespace ${NAMESPACE} \
                        --output wide

                    echo
                    echo "=========================================="
                    echo "Deployments"
                    echo "=========================================="

                    kubectl get deployments \
                        --namespace ${NAMESPACE}

                    echo
                    echo "=========================================="
                    echo "Services"
                    echo "=========================================="

                    kubectl get services \
                        --namespace ${NAMESPACE}

                    echo
                    echo "=========================================="
                    echo "Ingress"
                    echo "=========================================="

                    kubectl get ingress \
                        --namespace ${NAMESPACE}

                    echo
                    echo "=========================================="
                    echo "ReplicaSets"
                    echo "=========================================="

                    kubectl get replicasets \
                        --namespace ${NAMESPACE} \
                        --selector app=${APP_NAME}

                    echo
                    echo "=========================================="
                    echo "Current Deployment Image"
                    echo "=========================================="

                    kubectl get deployment ${APP_NAME} \
                        --namespace ${NAMESPACE} \
                        --output jsonpath='{.spec.template.spec.containers[?(@.name=="'${CONTAINER_NAME}'")].image}'

                    echo
                '''
            }
        }
    }

    // ================================================================
    // Actions performed after the stages finish
    // ================================================================
    post {

        success {
            echo "=========================================="
            echo "PIPELINE COMPLETED SUCCESSFULLY"
            echo "=========================================="

            echo "Git SHA       : ${env.GIT_SHA}"
            echo "Image deployed: ${env.IMAGE}"
        }

        failure {
            echo "=========================================="
            echo "PIPELINE FAILED"
            echo "=========================================="

            echo "Attempted image: ${env.IMAGE ?: 'Not created'}"
            echo "Check the deployment and rollback logs above."
        }

        always {
            echo "Pipeline execution completed."
        }
    }
}