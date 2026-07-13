allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Map the build directory for all subprojects to the root build folder
subprojects {
    val subproject = this
    subproject.layout.buildDirectory.value(rootProject.layout.projectDirectory.dir("../build/${subproject.name}"))
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    description = "Cleans the build directory"
    delete(rootProject.layout.buildDirectory)
}

// Global configuration for all subprojects to fix lStar resource errors
subprojects {
    val subproject = this
    if (!subproject.state.executed) {
        subproject.afterEvaluate {
            if (subproject.hasProperty("android")) {
                val android = subproject.extensions.getByName("android")
                if (android is com.android.build.gradle.BaseExtension) {
                    android.compileSdkVersion(35)
                }
            }
        }
    }
}
