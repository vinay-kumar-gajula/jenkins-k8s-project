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
                sh '''
                    set -e

                    echo "=== Git Commit ==="
                    git log --oneline -1

                    GIT_SHA=$(git rev-parse --short=7 HEAD)

                    echo "Git SHA: ${GIT_SHA}"

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
                
                script {
                    env.GIT_SHA = sh(
                        script: 'git rev-parse --short=7 HEAD',
                        returnStdout: true
                    ).trim()

                    // env.IMAGE = "${env.APP_NAME}:${env.GIT_SHA}"
		       env.IMAGE = "${env.APP_NAME}:does-not-exist"

                    echo "Image to build: ${env.IMAGE}"
                }
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

                    echo "=== Building Docker Image ==="
                    echo "Image: ${IMAGE}"

                    docker build \
                        -t "${IMAGE}" \
                        .

                    echo
                    echo "=== Docker Image ==="
                    docker images "${APP_NAME}"
                '''
            }
        }

        stage('Load Image into Kind') {
            steps {
                sh '''
                    set -e

                    echo "=== Loading Image into Kind ==="
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

                            echo "=== Applying Kubernetes manifests ==="

                            kubectl apply \
                                -f k8s/app/

                            echo
                            echo "=== Updating Web Application Image ==="

                            kubectl set image \
                                deployment/${APP_NAME} \
                                nginx=${IMAGE} \
                                -n ${NAMESPACE}

                            echo
                            echo "Deployment triggered."
                        '''

                        sh '''
                            set -e

                            echo "=== Waiting for Web Application Rollout ==="

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

                        error("Deployment failed. Previous version has been restored.")
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -e

                    echo "=== Pods ==="

                    kubectl get pods \
                        -n ${NAMESPACE} \
                        -o wide

                    echo
                    echo "=== Deployments ==="

                    kubectl get deployments \
                        -n ${NAMESPACE}

                    echo
                    echo "=== Services ==="

                    kubectl get services \
                        -n ${NAMESPACE}

                    echo
                    echo "=== Ingress ==="

                    kubectl get ingress \
                        -n ${NAMESPACE}

                    echo
                    echo "=== Current Image ==="

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
            echo "Image deployed: ${IMAGE}"
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
