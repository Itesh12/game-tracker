plugins {
    kotlin("jvm")
}

dependencies {
    implementation(project(":module-domain"))
    implementation(project(":module-shared"))
    implementation(kotlin("stdlib"))
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0")
    testImplementation(kotlin("test"))
}
