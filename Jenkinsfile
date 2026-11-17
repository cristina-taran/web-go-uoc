pipeline {
    agent any

    options {
        // We perform checkout explicitly in the Checkout stage below.
        skipDefaultCheckout(true)
    }

    environment {
        IMAGE = 'ghcr.io/cristina-taran/web-go-uoc'
        NAMESPACE = 'web-go-uoc'
    }

    triggers {
        githubPush()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    echo "Building ${env.IMAGE}:${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build image') {
            steps {
                sh '''#!/bin/sh
                    set -eu
                    command -v docker >/dev/null 2>&1 || { echo 'ERROR: Docker CLI is not installed on this Jenkins agent.'; exit 1; }
                    docker info >/dev/null 2>&1 || { echo 'ERROR: Jenkins cannot access the Docker daemon. Check that Docker is running and the Jenkins user can access its socket.'; exit 1; }
                    docker build --pull --tag "$IMAGE:$IMAGE_TAG" .
                '''
            }
        }

        stage('Publish image to GHCR') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'ghcr-credentials', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
                    sh '''#!/bin/sh
                        set -eu
                        printf '%s' "$GHCR_TOKEN" | docker login ghcr.io --username "$GHCR_USER" --password-stdin
                        trap 'docker logout ghcr.io >/dev/null 2>&1 || true' EXIT
                        docker push "$IMAGE:$IMAGE_TAG"
                    '''
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                sh '''#!/bin/sh
                    set -eu
                    kubectl apply -f k8s/namespace.yaml
                    kubectl apply -n "$NAMESPACE" -f k8s/
                    kubectl set image deployment/web-go-uoc web-go-uoc="$IMAGE:$IMAGE_TAG" -n "$NAMESPACE"
                    kubectl rollout status deployment/web-go-uoc -n "$NAMESPACE" --timeout=180s
                '''
            }
        }
    }
}