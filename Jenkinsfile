pipeline {
    agent any

    environment {
        KUBECONFIG = '/var/jenkins_home/kubeconfig'
        K8S_NAMESPACE = 'devops'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'd884b270-cd7b-45cf-bfd3-93bf44da9bed',
                    url: 'git@github.com:vinay-kumar-gajula/jenkins-k8s-project.git'
            }
        }

        stage('Verify') {
            steps {
                sh '''
                    set -e

                    echo "=== Git Commit ==="
                    git log --oneline -1

                    echo
                    echo "=== Kubernetes Client ==="
                    kubectl version --client

                    echo
                    echo "=== Kubernetes Context ==="
                    kubectl config current-context

                    echo
                    echo "=== Kubernetes Nodes ==="
                    kubectl get nodes

                    echo
                    echo "=== Existing Application ==="
                    kubectl get all -n ${K8S_NAMESPACE}
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

        stage('Deploy') {
            steps {
                sh '''
                    set -e

                    echo "=== Deploying application ==="

                    kubectl apply \
                        -f k8s/app/

                    echo
                    echo "=== Deployment Status ==="

                    kubectl rollout status \
                        deployment/web-app \
                        -n ${K8S_NAMESPACE} \
                        --timeout=120s

                    kubectl rollout status \
                        deployment/backend \
                        -n ${K8S_NAMESPACE} \
                        --timeout=120s
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    set -e

                    echo "=== Pods ==="
                    kubectl get pods -n ${K8S_NAMESPACE} -o wide

                    echo
                    echo "=== Services ==="
                    kubectl get svc -n ${K8S_NAMESPACE}

                    echo
                    echo "=== Deployments ==="
                    kubectl get deployments -n ${K8S_NAMESPACE}

                    echo
                    echo "=== Ingress ==="
                    kubectl get ingress -n ${K8S_NAMESPACE}
                '''
            }
        }
    }

    post {
        success {
            echo 'Kubernetes deployment completed successfully.'
        }

        failure {
            echo 'Pipeline failed. Check the console output.'
        }

        always {
            echo 'Pipeline completed.'
        }
    }
}
