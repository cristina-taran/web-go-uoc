pipeline {
    agent any

    options {
        // The Multibranch Pipeline checks out the branch explicitly once.
        skipDefaultCheckout(true)
    }

    environment {
        IMAGE = 'web-go-uoc'
        K8S_NAMESPACE = ''
        NODE_PORT = ''
        REPLICAS = ''
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()

                    if (env.BRANCH_NAME == 'test') {
                        env.K8S_NAMESPACE = 'web-go-uoc-test'
                        env.NODE_PORT = '30081'
                        env.REPLICAS = '1'
                        echo 'Branch test will deploy to the isolated test namespace.'
                    } else if (env.BRANCH_NAME == 'main') {
                        env.K8S_NAMESPACE = 'web-go-uoc'
                        env.NODE_PORT = '30080'
                        env.REPLICAS = '2'
                        echo 'Branch main will deploy to production.'
                    } else {
                        echo "Branch ${env.BRANCH_NAME} will run CI only; it has no deployment target."
                    }

                    echo "Building ${env.IMAGE}:${env.IMAGE_TAG}"
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

        stage('Deploy to Minikube') {
            when {
                anyOf {
                    branch 'test'
                    branch 'main'
                }
            }
            steps {
                sh '''#!/bin/sh
                    set -eu
                    sudo -n -u ubuntu -H /usr/local/sbin/web-go-uoc-deploy \
                      "$IMAGE_TAG" "$WORKSPACE" "$K8S_NAMESPACE" "$NODE_PORT" "$REPLICAS"
                '''
            }
        }
    }
}
