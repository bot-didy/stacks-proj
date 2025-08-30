#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const yaml = require("yaml");

console.log("🧪 Testing GitBook Integration...\n");

// Test 1: Check .gitbook.yaml configuration
function testGitBookConfig() {
  console.log("1️⃣  Testing GitBook Configuration (.gitbook.yaml)");

  try {
    const configPath = ".gitbook.yaml";
    if (!fs.existsSync(configPath)) {
      throw new Error(".gitbook.yaml not found");
    }

    const configContent = fs.readFileSync(configPath, "utf8");
    const config = yaml.parse(configContent);

    // Validate required fields
    if (!config.root) {
      throw new Error('Missing "root" field in .gitbook.yaml');
    }

    if (!config.structure) {
      throw new Error('Missing "structure" field in .gitbook.yaml');
    }

    if (!config.structure.readme) {
      throw new Error('Missing "structure.readme" field in .gitbook.yaml');
    }

    if (!config.structure.summary) {
      throw new Error('Missing "structure.summary" field in .gitbook.yaml');
    }

    console.log("   ✅ GitBook configuration is valid");
    console.log(`   📁 Root: ${config.root}`);
    console.log(`   📖 README: ${config.structure.readme}`);
    console.log(`   📋 Summary: ${config.structure.summary}`);
    console.log(`   📝 Format: ${config.format || "markdown"}\n`);

    return true;
  } catch (error) {
    console.log(`   ❌ Configuration test failed: ${error.message}\n`);
    return false;
  }
}

// Test 2: Check required files exist
function testRequiredFiles() {
  console.log("2️⃣  Testing Required Files");

  const requiredFiles = ["README.md", "SUMMARY.md"];
  let allFilesExist = true;

  requiredFiles.forEach((file) => {
    if (fs.existsSync(file)) {
      console.log(`   ✅ ${file} exists`);
    } else {
      console.log(`   ❌ ${file} missing`);
      allFilesExist = false;
    }
  });

  console.log();
  return allFilesExist;
}

// Test 3: Validate SUMMARY.md structure and linked files
function testSummaryStructure() {
  console.log("3️⃣  Testing SUMMARY.md Structure and Links");

  try {
    const summaryContent = fs.readFileSync("SUMMARY.md", "utf8");
    const lines = summaryContent.split("\n");

    let linkCount = 0;
    let validLinks = 0;
    let invalidLinks = [];

    lines.forEach((line, index) => {
      const linkMatch = line.match(/\[([^\]]+)\]\(([^)]+)\)/g);
      if (linkMatch) {
        linkMatch.forEach((link) => {
          const pathMatch = link.match(/\(([^)]+)\)/);
          if (pathMatch) {
            const filePath = pathMatch[1];
            linkCount++;

            if (fs.existsSync(filePath)) {
              validLinks++;
              console.log(`   ✅ ${filePath}`);
            } else {
              invalidLinks.push({ line: index + 1, path: filePath });
              console.log(`   ❌ ${filePath} (missing)`);
            }
          }
        });
      }
    });

    console.log(
      `\n   📊 Link Summary: ${validLinks}/${linkCount} links are valid`
    );

    if (invalidLinks.length > 0) {
      console.log("   🚨 Missing files:");
      invalidLinks.forEach((link) => {
        console.log(`      - Line ${link.line}: ${link.path}`);
      });
    }

    console.log();
    return invalidLinks.length === 0;
  } catch (error) {
    console.log(`   ❌ SUMMARY.md test failed: ${error.message}\n`);
    return false;
  }
}

// Test 4: Check directory structure
function testDirectoryStructure() {
  console.log("4️⃣  Testing Directory Structure");

  const expectedDirs = [
    "architecture",
    "developers",
    "contracts",
    "examples",
    "support",
  ];
  let allDirsExist = true;

  expectedDirs.forEach((dir) => {
    if (fs.existsSync(dir) && fs.statSync(dir).isDirectory()) {
      const files = fs.readdirSync(dir).filter((f) => f.endsWith(".md"));
      console.log(`   ✅ ${dir}/ (${files.length} files)`);
    } else {
      console.log(`   ❌ ${dir}/ missing`);
      allDirsExist = false;
    }
  });

  console.log();
  return allDirsExist;
}

// Test 5: Validate README.md content
function testReadmeContent() {
  console.log("5️⃣  Testing README.md Content");

  try {
    const readmeContent = fs.readFileSync("README.md", "utf8");

    // Check for basic structure
    const hasTitle = readmeContent.includes("# ");
    const hasLinks = readmeContent.includes("[") && readmeContent.includes("]");
    const hasStructure = readmeContent.length > 100; // Basic content check

    console.log(`   ${hasTitle ? "✅" : "❌"} Has main title`);
    console.log(`   ${hasLinks ? "✅" : "❌"} Contains links`);
    console.log(
      `   ${hasStructure ? "✅" : "❌"} Has substantial content (${
        readmeContent.length
      } chars)`
    );

    console.log();
    return hasTitle && hasLinks && hasStructure;
  } catch (error) {
    console.log(`   ❌ README.md test failed: ${error.message}\n`);
    return false;
  }
}

// Run all tests
function runAllTests() {
  console.log("🚀 Starting GitBook Integration Tests\n");

  const results = {
    config: testGitBookConfig(),
    files: testRequiredFiles(),
    summary: testSummaryStructure(),
    structure: testDirectoryStructure(),
    readme: testReadmeContent(),
  };

  // Summary
  console.log("📋 Test Results Summary:");
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━");

  Object.entries(results).forEach(([test, passed]) => {
    console.log(
      `${passed ? "✅" : "❌"} ${
        test.charAt(0).toUpperCase() + test.slice(1)
      } Test`
    );
  });

  const allPassed = Object.values(results).every((result) => result);
  console.log("━━━━━━━━━━━━━━━━━━━━━━━━━━");
  console.log(
    `${allPassed ? "🎉" : "⚠️"} Overall Status: ${
      allPassed ? "PASSED" : "FAILED"
    }`
  );

  if (allPassed) {
    console.log(
      "\n✨ GitBook integration is properly configured and ready to use!"
    );
    console.log("\n💡 Next steps:");
    console.log(
      "   - You can publish to GitBook by connecting your repository"
    );
    console.log(
      "   - Alternatively, use tools like @gitbook/cli for local building"
    );
    console.log(
      "   - Consider adding GitHub Actions for automated documentation deployment"
    );
  } else {
    console.log(
      "\n🔧 Please fix the failing tests before using GitBook integration."
    );
  }

  return allPassed;
}

// Install yaml dependency check
try {
  require("yaml");
} catch (error) {
  console.log("📦 Installing required dependency: yaml");
  require("child_process").execSync("npm install yaml", { stdio: "inherit" });
}

// Run the tests
runAllTests();
