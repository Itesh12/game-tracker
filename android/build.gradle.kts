allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://maven.webrtc.org")
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureSdk = Runnable {
        if (project.plugins.hasPlugin("com.android.application") || project.plugins.hasPlugin("com.android.library")) {
            project.extensions.configure<com.android.build.gradle.BaseExtension> {
                compileSdkVersion(36)
            }
            project.dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.2.0")
            project.dependencies.add("implementation", "org.jspecify:jspecify:1.0.0")
        }
    }
    if (project.state.executed) {
        configureSdk.run()
    } else {
        project.afterEvaluate { configureSdk.run() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
