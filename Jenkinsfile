pipeline {
    agent any

    options {
        // The Multibranch Pipeline checks out the branch explicitly once.
        skipDefaultCheckout(true)
    }

    environment {
        IMAGE = 'web-go-uoc'
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
                script {
                    def namespace
                    def nodePort
                    def replicas
                    if (env.BRANCH_NAME == 'test') {
                        namespace = 'web-go-uoc-test'
                        nodePort = '30081'
                        replicas = '1'
                    } else {
                        namespace = 'web-go-uoc'
                        nodePort = '30080'
                        replicas = '2'
                    }

                    withEnv([
                        "K8S_NAMESPACE=${namespace}",
                        "NODE_PORT=${nodePort}",
                        "REPLICAS=${replicas}"
                    ]) {
                        sh '''#!/bin/sh
                            set -eu
                            sudo -n -u ubuntu -H /usr/local/sbin/web-go-uoc-deploy \
                              "$IMAGE_TAG" "$WORKSPACE" "$K8S_NAMESPACE" "$NODE_PORT" "$REPLICAS"
                        '''
                    }
                }
            }
        }
    }
}
