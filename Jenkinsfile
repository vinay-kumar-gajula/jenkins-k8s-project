pipeline {

    agent any

    environment {
        APP_NAME     = "web-app"
        NAMESPACE    = "devops"
        KIND_CLUSTER = "devops-lab"
        KUBECONFIG   = "/var/jenkins_home/kubeconfig"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

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
                    echo "Tools"
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
                    env.GIT_SHA = sh(
                        script: 'git rev-parse --short=7 HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE = "${env.APP_NAME}:${env.GIT_SHA}"

                    echo "Image to build: ${env.IMAGE}"
                }
            }
        }

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

        stage('Build Docker Image') {
            steps {
                sh '''
                    set -e

                    echo "=========================================="
                    echo "Building Docker Image"
                    echo "=========================================="

                    echo "Image: ${IMAGE}"

                    docker build \
                        -t "${IMAGE}" \
                        .

                    echo
                    echo "Docker image built successfully."

                    docker images "${APP_NAME}"
                '''
            }
        }

        stage('Load Image into Kind') {
            steps {
                sh '''
                    set -e

                    echo "=========================================="
                    echo "Loading Image into Kind"
                    echo "=========================================="

                    echo "Cluster: ${KIND_CLUSTER}"
                    echo "Image: ${IMAGE}"

                    kind load docker-image \
                        "${IMAGE}" \
                        --name "${KIND_CLUSTER}"

                    echo
                    echo "Image successfully loaded into Kind."
                '''
            }
        }

        stage('Deploy') {
            steps {
                script {

                    try {

                        sh '''
                            set -e

                            echo "=========================================="
                            echo "Applying Kubernetes Manifests"
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
                        echo "DEPLOYMENT FAILED"
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
                        echo "Rolling Back Web Application"
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

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -e

                    echo "=========================================="
                    echo "Pods"
                    echo "=========================================="

                    kubectl get pods \
                        -n ${NAMESPACE} \
                        -o wide

                    echo
                    echo "=========================================="
                    echo "Deployments"
                    echo "=========================================="

                    kubectl get deployments \
                        -n ${NAMESPACE}

                    echo
                    echo "=========================================="
                    echo "Services"
                    echo "=========================================="

                    kubectl get services \
                        -n ${NAMESPACE}

                    echo
                    echo "=========================================="
                    echo "Ingress"
                    echo "=========================================="

                    kubectl get ingress \
                        -n ${NAMESPACE}

                    echo
                    echo "=========================================="
                    echo "Current Deployment Image"
                    echo "=========================================="

                    kubectl get deployment ${APP_NAME} \
                        -n ${NAMESPACE} \
                        -o jsonpath='{.spec.template.spec.containers[0].image}'

                    echo
                '''
            }
        }
    }

    post {

        success {
            echo "=========================================="
            echo "Pipeline completed successfully."
            echo "=========================================="

            echo "Git SHA      : ${GIT_SHA}"
            echo "Image deployed: ${IMAGE}"
        }

        failure {
            echo "=========================================="
            echo "Pipeline FAILED."
            echo "=========================================="

            echo "Check the logs above."
        }

        always {
            echo "Pipeline execution completed."
        }
    }
}
