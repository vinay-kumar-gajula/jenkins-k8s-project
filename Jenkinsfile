pipeline {
    agent any

    environment {
        APP_NAME    = 'web-app'
        NAMESPACE   = 'devops'
        KIND_CLUSTER = 'devops-lab'
        CONTAINER_NAME = 'nginx'
	KUBECONFIG      = '/var/jenkins_home/kubeconfig'
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
                    echo "=== Kind ==="
                    kind version

                    echo
                    echo "=== Kubernetes Context ==="
                    kubectl config current-context
                '''
            }
        }

        stage('Set Image Tag') {
            steps {
                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_NAME = "${env.APP_NAME}:${env.IMAGE_TAG}"

                    echo "======================================"
                    echo "Image: ${env.IMAGE_NAME}"
                    echo "======================================"
                }
            }
        }

        stage('Validate Manifests') {
            steps {
                sh '''
                    set -e

                    echo "=== Validating Kubernetes Manifests ==="

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
                    echo "Image: ${IMAGE_NAME}"

                    docker build \
                        -t "${IMAGE_NAME}" \
                        .
                '''
            }
        }

        stage('Load Image into Kind') {
            steps {
                sh '''
                    set -e

                    echo "=== Loading Image into Kind ==="
                    echo "Image: ${IMAGE_NAME}"
                    echo "Cluster: ${KIND_CLUSTER}"

                    kind load docker-image \
                        "${IMAGE_NAME}" \
                        --name "${KIND_CLUSTER}"
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                    set -e

                    echo "=== Deploying Kubernetes Manifests ==="

                    kubectl apply \
                        -f k8s/app/

                    echo
                    echo "=== Updating Application Image ==="

                    kubectl set image \
                        deployment/web-app \
                        "${CONTAINER_NAME}=${IMAGE_NAME}" \
                        --namespace "${NAMESPACE}"

                    echo
                    echo "=== Waiting for Rollout ==="

                    kubectl rollout status \
                        deployment/web-app \
                        --namespace "${NAMESPACE}" \
                        --timeout=120s

                    echo
                    echo "Web application rollout successful."
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -e

                    echo "=== Pods ==="

                    kubectl get pods \
                        --namespace "${NAMESPACE}" \
                        -o wide

                    echo
                    echo "=== Deployments ==="

                    kubectl get deployments \
                        --namespace "${NAMESPACE}"

                    echo
                    echo "=== Services ==="

                    kubectl get services \
                        --namespace "${NAMESPACE}"

                    echo
                    echo "=== Ingress ==="

                    kubectl get ingress \
                        --namespace "${NAMESPACE}"

                    echo
                    echo "=== Current Image ==="

                    kubectl get deployment web-app \
                        --namespace "${NAMESPACE}" \
                        -o jsonpath='{.spec.template.spec.containers[0].image}'

                    echo
                    echo
                    echo "=== Rollout History ==="

                    kubectl rollout history \
                        deployment/web-app \
                        --namespace "${NAMESPACE}"
                '''
            }
        }
    }

    post {

        success {
            echo "======================================"
            echo "Pipeline completed successfully."
            echo "Deployed image: ${IMAGE_NAME}"
            echo "======================================"
        }

        failure {
            echo "======================================"
            echo "Pipeline failed."
            echo "======================================"
        }
    }
}
