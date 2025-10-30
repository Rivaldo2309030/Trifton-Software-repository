import com.android.build.gradle.LibraryExtension

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:7.3.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    project.evaluationDependsOn(":app")
    val newSubprojectBuildDir: Directory = rootProject.layout.buildDirectory.dir(project.name).get()
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Force Kotlin version on subproject buildscripts
    buildscript {
        configurations.all {
            resolutionStrategy.eachDependency {
                if (requested.group == "org.jetbrains.kotlin" && requested.name.startsWith("kotlin-")) {
                    useVersion("1.9.22")
                }
            }
        }
    }

    // Fix for outdated plugins that don't set namespace
    if (project.name == "flutter_native_timezone") {
        project.plugins.withId("com.android.library") {
            project.extensions.findByType(LibraryExtension::class.java)?.apply {
                namespace = "com.whelksoft.flutter_native_timezone"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
