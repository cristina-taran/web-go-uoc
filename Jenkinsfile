pipeline {
    agent any

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
                }
            }
        }

        stage('Build and publish image') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'ghcr-credentials', usernameVariable: 'GHCR_USER', passwordVariable: 'GHCR_TOKEN')]) {
                    sh '''
                        echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GHCR_USER" --password-stdin
                        docker build -t "$IMAGE:$IMAGE_TAG" .
                        docker push "$IMAGE:$IMAGE_TAG"
                        docker logout ghcr.io
                    '''
                }
            }
        }

        stage('Deploy to Minikube') {
            steps {
                sh '''
                    kubectl apply -f k8s/namespace.yaml
                    kubectl apply -n "$NAMESPACE" -f k8s/
                    kubectl set image deployment/web-go-uoc web-go-uoc="$IMAGE:$IMAGE_TAG" -n "$NAMESPACE"
                    kubectl rollout status deployment/web-go-uoc -n "$NAMESPACE" --timeout=180s
                '''
            }
        }
    }
}
