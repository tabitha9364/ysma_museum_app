allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val projectNdkVersion = "25.2.9519653"

fun Any.setAndroidStringProperty(methodName: String, value: String) {
    javaClass.methods
        .firstOrNull { method ->
            method.name == methodName &&
                method.parameterTypes.size == 1 &&
                method.parameterTypes[0] == String::class.java
        }
        ?.invoke(this, value)
}

fun Any.setAndroidJavaCompatibility(version: JavaVersion) {
    val compileOptions =
        javaClass.methods
            .firstOrNull { method ->
                method.name == "getCompileOptions" &&
                    method.parameterTypes.isEmpty()
            }
            ?.invoke(this)
            ?: return

    compileOptions.javaClass.methods
        .firstOrNull { method ->
            method.name == "setSourceCompatibility" &&
                method.parameterTypes.size == 1 &&
                method.parameterTypes[0] == JavaVersion::class.java
        }
        ?.invoke(compileOptions, version)

    compileOptions.javaClass.methods
        .firstOrNull { method ->
            method.name == "setTargetCompatibility" &&
                method.parameterTypes.size == 1 &&
                method.parameterTypes[0] == JavaVersion::class.java
        }
        ?.invoke(compileOptions, version)
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

configurations.all {
    exclude(group = "com.android.support", module = "support-compat")
}

subprojects {
    afterEvaluate {
        extensions.findByName("android")?.let { androidExtension ->
            androidExtension.setAndroidStringProperty("setNdkVersion", projectNdkVersion)
            androidExtension.setAndroidJavaCompatibility(JavaVersion.VERSION_17)
        }
    }

    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }

    plugins.withId("kotlin-android") {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }

    plugins.withId("com.android.application") {
        extensions.findByName("android")?.let { androidExtension ->
            androidExtension.setAndroidStringProperty("setNdkVersion", projectNdkVersion)
            androidExtension.setAndroidJavaCompatibility(JavaVersion.VERSION_17)
        }
    }

    plugins.withId("com.android.library") {
        extensions.findByName("android")?.let { androidExtension ->
            androidExtension.setAndroidStringProperty("setNdkVersion", projectNdkVersion)
            androidExtension.setAndroidJavaCompatibility(JavaVersion.VERSION_17)

            if (name == "ar_flutter_plugin") {
                androidExtension.setAndroidStringProperty("setNamespace", "io.carius.lars.ar_flutter_plugin")
            }
        }
    }

    if (name == "permission_handler_android") {
        afterEvaluate {
            tasks.withType<JavaCompile>().configureEach {
                setSource(
                    source.filter { sourceFile ->
                        !sourceFile.absolutePath.replace('\\', '/').endsWith(
                            "permission_handler_android-10.3.6/android/src/main/java/com/baseflow/permissionhandler/PermissionHandlerPlugin.java"
                        )
                    }
                )
                source(
                    rootProject.file(
                        "patches/permission_handler_android/src/main/java/com/baseflow/permissionhandler/PermissionHandlerPlugin.java"
                    )
                )
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
