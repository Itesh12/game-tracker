plugins {
    kotlin("jvm")
}

dependencies {
    implementation(project(":module-domain"))
    implementation(project(":module-application"))
    implementation(kotlin("stdlib"))
    implementation("com.tngtech.archunit:archunit:1.3.0")
    implementation("junit:junit:4.13.2")
}
