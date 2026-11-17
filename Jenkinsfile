pipeline {
    agent any

    options {
        // The checkout is performed explicitly in the Checkout stage.
        skipDefaultCheckout(true)
    }

    environment {
        IMAGE = 'web-go-uoc'
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
                    echo "Building local image ${env.IMAGE}:${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build image') {
            steps {
                sh '''#!/bin/sh
                    set -eu
                    command -v docker >/dev/null 2>&1 || { echo 'ERROR: Docker CLI is not installed on this Jenkins agent.'; exit 1; }
                    docker info >/dev/null 2>&1 || { echo 'ERROR: Jenkins cannot access the Docker daemon.'; exit 1; }
                    docker build --pull --tag "$IMAGE:$IMAGE_TAG" .
                '''
            }
        }

        stage('Load and deploy to Minikube') {
            steps {
                sh '''#!/bin/sh
                    set -eu
                    sudo -n -u ubuntu -H /usr/local/sbin/web-go-uoc-deploy "$IMAGE_TAG" "$WORKSPACE"
                '''
            }
        }
    }
}