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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ✅ التعديل السحري بلغة Kotlin لحل مشكلة namespace لمكتبة البلوتوث
subprojects {
    afterEvaluate {
        if (hasProperty("android")) {
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                    val namespace = getNamespace.invoke(androidExt)
                    if (namespace == null) {
                        val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        setNamespace.invoke(androidExt, project.group.toString())
                    }
                } catch (e: Exception) {
                    // تجاهل
                }
            }
        }
    }
}