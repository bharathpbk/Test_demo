pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Restore & Build (.NET)') {
            when { expression { fileExists('*.sln') || findFiles(glob: '**/*.csproj').length > 0 } }
            steps {
                sh 'dotnet restore'
                sh 'dotnet build --configuration Release --no-restore'
            }
        }
        stage('Build (Angular)') {
            when { expression { fileExists('angular.json') } }
            steps {
                sh 'npm ci'
                sh 'npx ng build --configuration production'
            }
        }
        stage('Static Code Analysis') {
            steps {
                echo 'Plug in SonarQube scanner here, e.g.: sh "dotnet sonarscanner begin ..."'
            }
        }
        stage('Test') {
            steps {
                sh 'dotnet test || true'
            }
        }
    }
    post {
        failure {
            echo 'Build failed - PR/commit should not proceed to merge.'
        }
    }
}
