allprojects {
    repositories {
        google()
        mavenCentral()
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
    val configureNdk: (Project) -> Unit = { proj ->
        if (proj.hasProperty("android")) {
            val androidExt = proj.extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val method = androidExt.javaClass.getMethod("setNdkVersion", String::class.java)
                    method.invoke(androidExt, "30.0.16248370")
                } catch (_: Exception) {}
            }
        }
    }
    if (project.state.executed) {
        configureNdk(project)
    } else {
        project.afterEvaluate { configureNdk(project) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
