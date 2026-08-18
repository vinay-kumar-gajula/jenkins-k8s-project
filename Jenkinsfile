pipeline {
    agent any

    environment {
        APP_NAME = "web-app"
        NAMESPACE = "devops"
        KIND_CLUSTER = "devops-lab"
        IMAGE_NAME = "web-app"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Verify') {
            steps {
                sh '''
                    set -e

                    echo "=== Git Commit ==="
                    git log --oneline -1

                    echo
                    echo "=== Docker ==="
                    docker --version

                    echo
                    echo "=== Kubernetes Client ==="
                    kubectl version --client

                    echo
                    echo "=== Kubernetes Context ==="
                    kubectl config current-context

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

                    echo "=== Building Docker Image ==="

                    docker build \
                        -t "${IMAGE_NAME}:${BUILD_NUMBER}" \
                        .

                    echo
                    echo "=== Built Image ==="

                    docker images "${IMAGE_NAME}:${BUILD_NUMBER}"
                '''
            }
        }

        stage('Load Image into Kind') {
            steps {
                sh '''
                    set -e

                    echo "=== Loading Image into Kind ==="

                    kind load docker-image \
                        "${IMAGE_NAME}:${BUILD_NUMBER}" \
                        --name "${KIND_CLUSTER}"

                    echo
                    echo "Image loaded into Kind successfully."
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    set -e

                    echo "=== Applying Kubernetes manifests ==="

                    kubectl apply \
                        -f k8s/app/

                    echo
                    echo "=== Updating web-app image ==="

                    kubectl set image \
                        deployment/"${APP_NAME}" \
                        nginx="${IMAGE_NAME}:${BUILD_NUMBER}" \
                        --namespace "${NAMESPACE}"

                    echo
                    echo "=== Waiting for web-app rollout ==="

                    kubectl rollout status \
                        deployment/"${APP_NAME}" \
                        --namespace "${NAMESPACE}" \
                        --timeout=120s
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -e

                    echo "=== Pods ==="
                    kubectl get pods \
                        -n "${NAMESPACE}" \
                        -o wide

                    echo
                    echo "=== Deployments ==="
                    kubectl get deployments \
                        -n "${NAMESPACE}"

                    echo
                    echo "=== Services ==="
                    kubectl get services \
                        -n "${NAMESPACE}"

                    echo
                    echo "=== Ingress ==="
                    kubectl get ingress \
                        -n "${NAMESPACE}"

                    echo
                    echo "=== Current Image ==="

                    kubectl get deployment "${APP_NAME}" \
                        -n "${NAMESPACE}" \
                        -o jsonpath='{.spec.template.spec.containers[0].image}'

                    echo
                '''
            }
        }
    }

    post {
        success {
            echo 'Kubernetes deployment completed successfully.'
        }

        failure {
            echo 'Pipeline failed.'
        }
    }
}
