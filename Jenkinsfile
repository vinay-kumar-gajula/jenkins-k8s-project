pipeline {

    agent any

    environment {
        APP_NAME       = "web-app"
        NAMESPACE      = "devops"
        KIND_CLUSTER   = "devops-lab"
        KUBECONFIG     = "/var/jenkins_home/kubeconfig"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Prepare') {
            steps {
                script {

                    env.GIT_SHA = sh(
                        script: 'git rev-parse --short=7 HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE = "${env.APP_NAME}:${env.GIT_SHA}"

                    echo "=========================================="
                    echo "Git SHA      : ${env.GIT_SHA}"
                    echo "Docker Image : ${env.IMAGE}"
                    echo "=========================================="
                }

                sh '''
                    set -e

                    echo "=== Git Commit ==="
                    git log --oneline -1

                    echo
                    echo "=== Tools ==="

                    docker --version
                    kubectl version --client
                    kind version

                    echo
                    echo "=== Kubernetes Context ==="

                    kubectl config current-context || true

                    echo
                    echo "=== Kubernetes Nodes ==="

                    kubectl get nodes
                '''
            }
        }

        stage('Validate Manifests') {
            steps {
                sh '''
                    set -e

                    echo "=== Validating Kubernetes manifests ==="

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
                    echo "Image: ${IMAGE}"
                    echo "=========================================="

                    docker build \
                        -t "${IMAGE}" \
                        .

                    echo
                    echo "=== Built Image ==="

                    docker images "${APP_NAME}" \
                        --format 'table {{.Repository}}\\t{{.Tag}}\\t{{.ID}}\\t{{.Size}}'
                '''
            }
        }

        stage('Load Image into Kind') {
            steps {
                sh '''
                    set -e

                    echo "=========================================="
                    echo "Loading Image into Kind"
                    echo "Cluster: ${KIND_CLUSTER}"
                    echo "Image  : ${IMAGE}"
                    echo "=========================================="

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

                        echo "=== Rolling Back Web Application ==="

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

                        echo "Rollback completed."

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
                    echo "Expected Image"
                    echo "=========================================="

                    echo "${IMAGE}"

                    echo
                    echo "=========================================="
                    echo "Actual Deployment Image"
                    echo "=========================================="

                    ACTUAL_IMAGE=$(kubectl get deployment ${APP_NAME} \
                        -n ${NAMESPACE} \
                        -o jsonpath='{.spec.template.spec.containers[0].image}')

                    echo "${ACTUAL_IMAGE}"

                    echo
                    echo "=========================================="
                    echo "Verifying Image"
                    echo "=========================================="

                    if [ "${ACTUAL_IMAGE}" != "${IMAGE}" ]; then
                        echo "ERROR: Deployment image does not match expected image."
                        echo "Expected: ${IMAGE}"
                        echo "Actual  : ${ACTUAL_IMAGE}"
                        exit 1
                    fi

                    echo "Image verification successful."

                    echo
                    echo "=========================================="
                    echo "Rollout History"
                    echo "=========================================="

                    kubectl rollout history \
                        deployment/${APP_NAME} \
                        -n ${NAMESPACE}

                    echo
                    echo "=========================================="
                    echo "Deployment Verification Successful"
                    echo "=========================================="
                '''
            }
        }
    }

    post {

        success {
            echo "=========================================="
            echo "Pipeline completed successfully."
            echo "Image deployed: ${IMAGE}"
            echo "Git SHA: ${GIT_SHA}"
            echo "=========================================="
        }

        failure {
            echo "=========================================="
            echo "Pipeline FAILED."
            echo "Check the logs above."
            echo "=========================================="
        }

        always {
            echo "Pipeline execution completed."
        }
    }
}
