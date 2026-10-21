The strongest way to teach this project is not to narrate the code line by line. It's to let students follow your engineering decisions: what problem you're solving, why you chose this design, what could go wrong, and how each new piece changes the system.

Your central teaching idea is excellent: build once, verify once, and promote the same artifact everywhere. I would structure the video like an engineer designing a tiny delivery platform from scratch, with each section answering a question that naturally leads to the next.

Below is a full, presenter-ready script with spoken dialogue, coding directions, terminal demonstrations, and reasoning to explain on camera. It is designed to sound like an engineer thinking aloud rather than someone reading documentation.

# Video script: Building a CI/CD platform from scratch in Go

## Building a Bare-Bones CI/CD Harness

A hands-on engineering walkthrough

Suggested runtime: 45–60 minutes, including live coding and demonstrations

We'll build a working delivery system, not just a collection of scripts. By the end, students will understand the lifecycle of a binary from source code to a running service, including testing, packaging, deployment, health checks, rollback, promotion, and runtime configuration.

## Part 1 — The opening: Why build this?

Time: 0:00–3:00 · Show a terminal, a running application, and the project structure.

Imagine you've just finished building a feature.

It works on your machine. Your tests pass. You're ready to ship it.

But now we have a few questions.

How do we know the code that passed our tests is the same code running in production?

If the new version breaks production, how do we get the previous version back?

And if something works in staging, how do we move it to production without accidentally building a slightly different version of the application?

These sound like deployment questions, but underneath them is a much more fundamental engineering problem: **how do we preserve trust as software moves from development to production?**

That's what I want to explore in this project.

Instead of starting with Jenkins, Harness, GitHub Actions, or a cloud deployment platform, we're going to build a very small delivery harness ourselves, using Go and a few files on disk.

We'll have an application, a command-line tool, versioned builds, a testing gate, immutable artifacts, two environments, health checks, automatic rollback, and promotion between environments.

And I want to be clear about something: we're not trying to recreate every feature of a production CI/CD platform. We're trying to understand the engineering primitives those platforms coordinate.

My guiding rule throughout this project is simple:

**Build once, verify once, deploy the exact same artifact everywhere.**

Every design decision we make should support that rule.

By the end, I don't just want you to know how to run a deployment command. I want you to understand why the command is designed that way, what assumptions it makes, and what breaks when those assumptions aren't true.

### On-screen action

Show the intended lifecycle:

Source code

The thing we want to deliver

Build + test gate

Produce a versioned binary only if tests pass

Versioned artifact

Binary plus metadata

Staging

Verify the deployment

Production

Promote the same artifact

Say:

"The important part of this diagram isn't the number of commands. It's the direction of movement. We go from source code to a specific binary, from that binary to a packaged artifact, and from that artifact to an environment. Once we've built the binary, nothing downstream should compile the application again."

## Part 2 — Define the boundary of the system

Time: 3:00–6:00 · Create the module and explain the separation of responsibilities.

Before writing code, I want to make one architectural decision.

I'm going to separate the application we're delivering from the tool that delivers it.

The application is the cargo. The harness is the delivery mechanism.

That distinction matters because I don't want the application to know how deployments work. It shouldn't need to know about staging directories, production ports, rollback history, or artifact packaging.

Its job is to serve requests.

The harness has a different responsibility: it coordinates the lifecycle of that application.

It builds it, tests it, packages it, starts it, checks whether it's healthy, and tracks which version belongs to each environment.

I'm also going to keep this implementation local. Instead of introducing Docker, Kubernetes, a cloud account, a database, or a distributed control plane, we'll represent the system with directories, files, operating-system processes, and HTTP requests.

That's a deliberate trade-off.

We're reducing the number of moving parts so we can study the delivery logic itself. Later, we could replace these local mechanisms with containers, a remote artifact registry, or an orchestration platform without changing the core concepts.

### On-screen action

Run:

```
mkdir -p harness-project/app harness-project/cmd/harness
cd harness-project
go mod init harness-project
```

Explain the layout:

```
harness-project/
├── go.mod
├── app/
└── cmd/
    └── harness/
```

Say:

"I'm also organizing the CLI by responsibility. The entry point will dispatch commands; the build code will handle builds; deployment code will handle processes and environments. As this grows, I don't want one giant `main.go` containing every operation."

Engineering note to explain: These files will all belong to the same Go `main` package, so functions such as `cmdBuild` and `deployArtifactTo` can call each other without creating a package for every small concern. That's a reasonable choice for a compact teaching project.

## Part 3 — Build the application before building the pipeline

Time: 6:00–11:00 · Create `app/main.go` and run the service.

### What to code

Use the `app/main.go` implementation from your project. Before typing, introduce the three endpoints and the build-time version.

Now let's build the smallest possible application that can teach us something useful about delivery.

I want three behaviors.

First, a health endpoint. The harness needs a way to ask, "Is the application responding successfully?"

Second, a version endpoint. A successful HTTP response alone doesn't tell us which release we're talking to. If I have version four running in staging and version three in production, I want to be able to prove that.

And third, a normal application endpoint that returns a greeting. We'll use this later to demonstrate feature flags.

Notice that I'm deliberately keeping the application boring. I don't want business logic to distract us from the delivery system.

The first interesting decision is this variable:

`var Version = "dev"`

Why is that useful?

Because I can compile the application and inject a different value into this variable at build time. That gives every build an identity that the application itself can report.

The application doesn't need to read its version from a configuration file at startup. The version is compiled into the binary.

That distinction becomes useful when we're debugging production. We can ask the running process which version it is, rather than trusting a deployment log that says what we intended to deploy.

Next, look at `PORT`.

I'm keeping the listening port configurable through an environment variable. That means the same executable can run on different ports without being recompiled.

Finally, look at `FEATURE_MESSAGE`.

This is another runtime setting. It changes the application's response without changing the binary.

So we've already introduced two different kinds of configuration: version identity, which we inject during compilation, and runtime behavior, which we configure through environment variables.

That distinction will matter later when we promote the same artifact between environments.

### Demonstration

Run the app and query the endpoints:

```
PORT=9001 go run ./app &
sleep 1

curl -s localhost:9001/version
curl -s localhost:9001/health
curl -s localhost:9001/

kill %1
```

Say:

"Right now, the version says `dev`. That's fine for local development, but it's not enough for a delivery system. I want the build process to give this binary an identity that stays with it wherever it runs."

### Explain the design choices

- `/health` answers whether the service is responding.
- `/version` answers which version the service claims to be running.
- `PORT` makes the binary reusable across environments.
- `FEATURE_MESSAGE` demonstrates that deployment configuration and application code are not the same thing.

Teaching point: A health check is not proof that every business operation works correctly. It's a deliberately small signal that we can use to demonstrate deployment verification.

## Part 4 — The CLI and the first build

Time: 11:00–17:00 · Create `cmd/harness/main.go` and `build.go`.

### Presenter script

Now we have something to deliver. Let's build the tool that will deliver it.

I want the interface to be a command-line tool, because commands make the responsibilities explicit. Instead of hiding everything inside one script, we'll have operations such as `build`, `package`, `deploy`, and `rollback`.

I'll start with a command dispatcher.

The dispatcher has one job: figure out which operation the user requested and pass the remaining arguments to the corresponding function.

It shouldn't contain the implementation of deployment or packaging itself. That would mix interface code with operational logic.

Next, I'm introducing a directory called `_harness`.

Everything the harness generates will live there: compiled binaries, packaged artifacts, environment state, and the build counter.

This is partly organization, but it's also a useful boundary. Source code lives in the project; generated delivery state lives in a separate directory.

Now let's implement the first command: `build`.

Here's the first problem I want to solve. If I build the application several times, how do I distinguish the outputs?

For this tutorial, I'll use a simple increasing counter: `v1`, `v2`, `v3`, and so on.

A production system might use a Git commit SHA, a release identifier, or a semantic version. I'm choosing a counter because it makes the lifecycle easy to follow on screen.

The counter is stored on disk so it survives between separate invocations of the CLI.

The build command reads the counter, increments it, writes the new value, and compiles the application into a version-specific filename.

Then we use Go's linker flags to inject that version into `main.Version`.

The resulting binary is called something like `app-v1`.

When we build again, we get `app-v2`, not an overwrite of `app-v1`.

This is the beginning of our artifact history.

One important distinction: unique version names are not the same thing as fully reproducible builds. A counter makes outputs identifiable; reproducibility means being able to recreate equivalent build outputs from controlled inputs. We'll focus on identity and artifact preservation first, and I'll call out the extra controls a production system would need.

### On-screen action

Create the dispatcher and build implementation from the project.

Add temporary stubs for commands that haven't been implemented yet, as shown in your guide.

Then run:

```
go build -o harness ./cmd/harness

./harness build
./harness build

ls -la _harness/builds/
```

Run one version:

```
PORT=9002 ./_harness/builds/app-v2 &
sleep 1
curl -s localhost:9002/version
kill %1
```

### What to emphasize on camera

### Three important distinctions

Version identity

The label `v2` tells us which build we're referring to.

Artifact preservation

Keeping `app-v1` and `app-v2` lets us refer back to previous outputs.

Build provenance

Knowing which source, toolchain, dependencies, and build settings produced a binary is a separate concern.

Say:

"Notice how we're beginning to separate identity from location. A version is an identity. A path such as `_harness/builds/app-v2` is where that particular build happens to be stored. Eventually, the same version will have a packaged location and a running location too."

## Part 5 — Testing as a gate, not a suggestion

Time: 17:00–23:00 · Add tests and wire them into `build`.

### Presenter script

At this point, our build command works, but it has a problem: it will happily compile code that we already know is broken.

That's not a great default for a delivery tool.

I want the command to enforce a rule. If the tests fail, the build should not produce a new shippable binary.

This is what people mean when they talk about a quality gate in a delivery pipeline.

Let's start with a test for the health endpoint.

There's a testing detail worth understanding here. Go gives us `httptest`, which lets us exercise HTTP handlers without opening a real network port. That makes tests fast and predictable.

For the final version of this project, I would also make sure the test exercises the actual handler used by the application, rather than recreating the handler inside the test. Otherwise, we could accidentally test a correct copy of the behavior while the real application is broken.

Now let's add `runTests`.

I'm making this a separate function because I want two entry points to share the same testing behavior: a standalone `harness test` command and the automatic test gate inside `harness build`.

This is a small example of a useful design principle: when two commands need the same operation, implement the operation once and have both commands call it.

Then we wire the test gate into `cmdBuild`, before we allocate the next version and compile the binary.

Why before the build?

Because a failed test shouldn't advance the version counter or leave a new build artifact behind.

Let's prove that behavior instead of just trusting the code.

### On-screen action

Run a successful build:

```
./harness build
```

Temporarily change the test to expect `"broken\n"` instead of `"ok\n"`.

Then run:

```
./harness build
echo "exit code: $?"
ls _harness/builds/
```

Restore the test.

### Explain the result

Say:

"This is the difference between a script that runs commands and a harness that enforces policy. The test command isn't merely convenient. It's a condition that must be satisfied before the system allows a new build to proceed."

Then clarify an important boundary:

"The gate we've implemented tests the source tree immediately before compilation. It doesn't automatically prove that every possible behavior of the compiled binary is correct. In a more complete pipeline, we'd also test the built artifact, run integration tests, and potentially perform security and compatibility checks."

## Part 6 — From a binary to a deployable artifact

Time: 23:00–28:00 · Implement `package.go`.

### Presenter script

We've got versioned binaries now, but I don't want the deployment system to reach into the build directory and grab an arbitrary file.

I want a clear distinction between something we've compiled and something we're treating as a deployable release.

That's why I'm introducing the package command.

The package command takes a specific build, copies the binary into an artifact directory, and writes metadata alongside it.

The metadata contains the version, when the binary was built according to its file modification time, and when we packaged it.

Why bother with metadata if the binary already reports its version?

Because the binary tells us one part of the story, while the artifact directory gives us a place to attach information about the delivery unit.

As the system grows, that metadata could include the Git commit, build environment, dependency information, test results, checksums, or a software bill of materials.

For now, we're keeping it small enough to understand.

Notice the directory structure:

`builds` contains raw compiled binaries.

`artifacts` contains the binaries we intend to deploy, together with their metadata.

This is the boundary I care about. Deployment should consume an existing artifact. It shouldn't reach back into the source tree and compile something new.

One caveat: copying a file into an artifact directory doesn't make it immutable by itself. Our current implementation can overwrite an existing artifact version. A production-quality version should reject duplicate versions, verify checksums, and treat published artifacts as read-only.

### On-screen action

```
./harness package
find _harness/artifacts -type f
cat _harness/artifacts/v3/metadata.json
```

Adapt the version in the last command to the actual build you're packaging.

Say:

"Now we have a deployable unit with an identity and some basic metadata. The next question is: how do we move it into a running environment without losing track of what we've deployed?"

## Part 7 — Deployment: turning an artifact into a running process

Time: 28:00–37:00 · Implement `deploy.go` and explain environment state.

### Presenter script

This is where our project begins to feel like a delivery platform.

So far, everything has happened before the application starts running. Now we need to take an artifact, put it into an environment, start it, and record what happened.

I'm going to simulate two environments: staging and production.

Each environment gets its own directory and its own port. Staging will listen on 8081, and production will listen on 8082.

This isn't how we'd normally isolate real production environments. In a real system, we'd have stronger isolation and probably a service manager, containers, or an orchestrator. But fixed ports and local processes are enough to teach the lifecycle.

First, I need a way to stop the currently tracked process.

Then I need a way to place the new binary into the environment and start it.

I also need to record which version is current and which version was there before.

That brings us to an important distinction: desired state versus observed state.

A file called `CURRENT_VERSION` is our record of what we intended to deploy. The `/version` endpoint is evidence of what the running application reports.

Those are not identical guarantees. The file could say one thing while the process is dead or serving another version. That's why we'll add health checks and later improve our verification.

Now, look at the binary replacement function.

I'm copying the new executable to a temporary file next to its destination, then renaming the temporary file into place.

Why?

Because writing directly over an executable that another process is using can cause problems, especially on Linux. Renaming a prepared file avoids truncating the destination in place and gives us an atomic filesystem name change when the filesystem supports it.

But here's an important nuance: atomic file replacement is not the same thing as an atomic deployment. Our current design stops the old process before starting the new one, so there can be downtime. A real blue-green deployment would start a separate instance and switch traffic only after verification.

Next, we launch the application with `exec.Command`.

We give it its environment variables, direct its output to a log file, and record its process ID.

We're using a detached session so the process can survive after the CLI exits. This is a local operating-system demonstration, not a substitute for a real process supervisor.

Finally, `deployArtifactTo` coordinates these steps. It takes an environment and a version, finds the already-packaged binary, prepares the environment, replaces the executable, records the version, and starts the application.

Notice what isn't happening anywhere in this function.

We are not running `go build`.

We are not compiling the source code again.

We are taking an existing artifact and deploying it.

That is the rule we established at the beginning, now enforced by the structure of the code.

### On-screen action

Build the CLI and deploy:

```
./harness deploy staging
sleep 1

curl -s localhost:8081/version
curl -s localhost:8081/
```

Redeploy a newer version:

```
./harness build
./harness package
./harness deploy staging
```

Compare the PID before and after.

### Explain the operational trade-offs

- `CURRENT_VERSION` and `PREVIOUS_VERSION` are local state records.
- `pid` identifies the process the harness believes it manages.
- `app.log` captures stdout and stderr.
- The environment port determines where health checks and requests go.
- Replacing the binary and starting the process are distinct operations.

Say:

"I want you to notice that deployment is a sequence of state transitions. The system has a current version, an incoming version, a process to stop, a binary to replace, and a new process to start. The complexity comes from what happens when any one of those steps fails."

Important engineering note: The tutorial's simple PID management is not safe against every failure mode, such as PID reuse, stale PID files, or an unresponsive process. A robust implementation would verify process identity, wait for termination, and fail if the old process cannot be stopped instead of assuming it has exited.

## Part 8 — Health checks and automatic rollback

Time: 37:00–44:00 · Implement `health.go` and `rollback.go`.

### Presenter script

Let's say the deployment command returns successfully.

Does that mean the deployment succeeded?

Not necessarily.

It might mean that we copied the binary successfully, started a process, and wrote a version number to disk. But the application could still fail to start correctly, crash immediately, or return errors when we send it requests.

So I want to define a more useful success condition.

A deployment is successful only if the new application passes a health check.

We'll implement that with a small HTTP client that calls the environment's `/health` endpoint.

There's one detail I want to get right: applications don't necessarily start responding the instant their process is created. That's why we'll retry a few times rather than making a single request and immediately declaring failure.

We'll also give each request a timeout. Without timeouts, a request that never completes could hang the harness indefinitely.

Now, a successful HTTP status is a deliberately basic health policy. We're not checking database connectivity, downstream dependencies, latency, or whether the application is returning correct business results. Those would be reasonable extensions.

Next comes rollback.

The idea is simple: when we deploy a new version, we record the version that was previously running. If the new deployment fails its health check, we can deploy the previous artifact again.

And notice the implementation strategy: rollback doesn't need a separate binary installation mechanism. It calls the same deployment function with an older version.

I like this because it reduces the number of special cases in the system.

Deploying version seven and rolling back to version six are fundamentally the same operation: put a particular artifact into an environment. The difference is how we choose the version.

Now let's test this under failure, because a rollback feature that only works when everything is healthy isn't very useful.

### Demonstration: simulate a broken release

First, verify a healthy deployment:

```
./harness deploy staging
./harness health staging
```

Now modify the health handler to return HTTP 500, as shown in your project.

Build, package, and deploy the broken version:

```
./harness build
./harness package
./harness deploy staging

echo "exit code: $?"
```

Then inspect:

```
cat _harness/environments/staging/CURRENT_VERSION
curl -s localhost:8081/version
```

### What to say during the failure

This is the moment I want you to pay attention to.

The deployment starts, but the health check fails. The harness then attempts to restore the previous version.

The key idea is that deployment isn't just a command that copies files. It's a process with a success condition and a recovery path.

This is also why I'm keeping previous artifacts around. If we overwrote every old binary with the newest one, we'd have nothing reliable to deploy during rollback.

One subtlety: our current rollback implementation restores the previous artifact, but it doesn't independently verify that the restored version is healthy before reporting that rollback has completed. A production implementation should health-check the rollback too and clearly report when recovery itself fails.

And remember, our health endpoint is intentionally simplistic. Passing it proves that the endpoint returned HTTP 200. It doesn't prove that the entire application is healthy.

For this exercise, though, we've demonstrated the core mechanism: a deployment that fails verification should not be treated as a successful release.

### Engineering discussion: why this matters

Deployment succeeds

The new version starts and satisfies the configured health check.

Deployment fails verification

The harness attempts to redeploy the previous version and reports the failed release.

Recovery also fails

The system must report that the environment may remain unhealthy; it must not pretend rollback succeeded.

Presenter transition:

"We can now deploy and recover within staging. The next question is how to move a release from staging to production without creating a second build."

## Part 9 — Promotion: the same artifact, another environment

Time: 44:00–49:00 · Implement `promote.go` and `status.go`.

### Presenter script

This is the central idea of the entire project.

Imagine we've tested version eight, packaged it, deployed it to staging, and verified that it behaves as expected.

Now we want to release it to production.

One approach would be to run the build command again and deploy the new output.

But that introduces another build. Even if the source code hasn't changed, the resulting output could differ because of changes in dependencies, toolchains, build settings, or the build environment.

If staging and production are running outputs from separate builds, we've created uncertainty that we didn't need to create.

So instead, I'm going to implement promotion.

Promotion reads the version recorded in the source environment and deploys that artifact to the target environment.

It doesn't accept a new version argument. That is intentional. The source environment determines what we're promoting.

There's a useful policy decision here: the command represents the release process we want people to follow, rather than giving them another way to pick an arbitrary build.

Now, we also need a status command.

I don't want the only way to understand the system to be remembering which commands I've run. I want one place to ask: what's deployed in each environment, and does it appear healthy?

The status command reads the current version and checks the environment's health.

This gives us a simple operational view of the system.

Let's deploy to staging, promote to production, and then compare the files.

If we've done this correctly, both environments should be running the same application binary from the same artifact version.

### On-screen action

```
./harness status
./harness promote staging production
./harness status
```

Compare the artifact with the deployed binary:

```
diff _harness/artifacts/vN/app \
     _harness/environments/production/app
```

Replace `vN` with the actual promoted version.

Then:

```
curl -s localhost:8081/version
curl -s localhost:8082/version
```

### Explain the result

Say:

"The matching version responses are useful, but the byte-for-byte comparison is stronger evidence that the two executable files are identical. The version endpoint reports identity; `diff` verifies the actual file contents."

Then explain a limitation honestly:

"Promotion in this implementation reads the source environment's recorded version. It doesn't yet prove that the source is currently healthy, nor does it prove that the version previously passed a complete release approval process. A production system should verify those conditions before permitting promotion."

### Why `status` deserves its own command

Status isn't just a convenience feature. It gives the system a basic way to observe its own state.

A real delivery platform may expose richer deployment histories, health signals, audit events, rollout progress, and alerts. Our local status command is the smallest version of that operational view.

## Part 10 — Feature flags: changing behavior without rebuilding

Time: 49:00–54:00 · Implement `flag.go` and demonstrate runtime configuration.

### Presenter script

So far, we've treated every code change as a new version that needs to be built and deployed.

But sometimes we want to change application behavior without changing the code currently running.

That's where feature flags come in.

Our application already reads `FEATURE_MESSAGE` from the environment. All we need now is a command that lets us configure that value independently for staging and production.

I'm going to store the flag value in a file belonging to each environment.

When the harness starts the application, it reads that file and injects the value into the process environment.

This is a deliberately minimal implementation. It doesn't have targeting rules, percentage rollouts, user-level evaluation, or a remote configuration service. But it demonstrates the fundamental separation between deploying code and controlling runtime behavior.

Let's enable a feature in staging.

The application should change its response, while production continues to use its existing configuration.

That's a useful property because we can test certain behavior in a limited environment without having to create a different binary for that environment.

One important detail: in this implementation, the flag is read when the application starts. Changing the file alone doesn't update a running process. We need to restart the application, which our deploy command currently does.

A more sophisticated feature flag system could evaluate configuration dynamically without restarting the service.

And here's a policy distinction I want you to understand: promoting an artifact and promoting configuration are different operations. The same binary can run with different flags, and moving a binary between environments doesn't automatically mean their configuration should become identical.

### Demonstration

```
./harness flag staging "new-checkout-flow"
./harness deploy staging

curl -s localhost:8081/
curl -s localhost:8082/
```

Then enable the same flag in production:

```
./harness flag production "new-checkout-flow"
./harness deploy production

curl -s localhost:8082/
./harness status
```

### Narration

"Notice that we didn't compile anything new. We changed runtime configuration, restarted the process, and observed different behavior. That's a small but important example of progressive delivery: separating when code is released from when a feature is enabled."

One caveat to point out: a feature flag isn't automatically a canary deployment. We've demonstrated environment-level configuration, not gradual traffic shifting or a percentage-based rollout.

## Part 11 — Final walkthrough: what we've actually built

Time: 54:00–58:00 · Run the complete workflow and review the state on disk.

### Presenter script

Let's step back and look at what we've built.

We started with an HTTP application that had almost no delivery infrastructure around it.

Then we introduced a build command that assigns a version to each compiled binary.

We added a test gate so that known test failures prevent new builds.

We separated compiled binaries from packaged artifacts and attached metadata to those artifacts.

We introduced staging and production as independent environments, with separate ports and process state.

We added health checks, rollback, promotion, status reporting, and a simple feature flag.

Each command does one focused thing, and each command manipulates a small amount of explicit state.

That's intentional. I want the system to be understandable enough that we can reason about its behavior without having to mentally simulate a huge platform.

But I also want to distinguish what we've demonstrated from what we've guaranteed.

We've demonstrated versioned binaries and a workflow that reuses packaged artifacts.

We haven't built a production-grade artifact registry, a fully reproducible build system, a secure deployment controller, or a distributed orchestration platform.

Our state is stored in local files, our environments are local processes, and our health policy is deliberately basic.

Those limitations aren't a failure of the exercise. They're part of the exercise.

The goal was to understand the core mechanics before adding the complexity of real infrastructure.

If you understand how these primitives fit together, the tools you encounter later become much easier to reason about.

You can look at a pipeline and ask: where is the artifact created? Where is it tested? What identifies the release? What state does the deployment controller maintain? What happens if a step fails? And how do we prove which version is running?

Those are the questions I wanted this project to teach.

### Final terminal demonstration

Run the commands in sequence, using an existing healthy artifact:

```
./harness test
./harness build
./harness package
./harness deploy staging
./harness health staging
./harness promote staging production
./harness status
```

Then show the running versions:

```
curl -s localhost:8081/version
curl -s localhost:8082/version
```

Show the artifact layout:

```
find _harness -maxdepth 4 -type f
```

And finish with the same-binary comparison:

```
diff _harness/artifacts/vN/app \
     _harness/environments/staging/app

diff _harness/artifacts/vN/app \
     _harness/environments/production/app
```

Use the actual version in place of `vN`.

## Part 12 — What I would improve next

Time: 58:00–60:00 · End with the engineering lessons, not another code dump.

If I were taking this project beyond the tutorial, I wouldn't immediately add more commands. I'd strengthen the guarantees behind the commands we already have.

First, I'd make artifacts genuinely immutable. Once a version has been published, the harness should reject attempts to replace it. I'd calculate a cryptographic checksum and verify the artifact before deploying it.

Second, I'd improve the build process. I'd record the source commit, Go version, dependency information, and build settings. If I wanted reproducible builds, I'd control those inputs and verify that independent builds produce the expected equivalent output.

Third, I'd make deployment safer. I'd introduce stronger process supervision, explicit deployment states, and a recovery strategy for failures at every step. I'd also ensure rollback itself is health-checked.

Fourth, I'd replace the simplistic deployment strategy with a blue-green deployment. We would start the new version separately, verify it, and only then switch traffic. That would reduce the downtime inherent in stopping the old process before starting the new one.

Fifth, I'd add integration tests that exercise the actual application and the complete delivery workflow, not just isolated functions.

And finally, I'd move the local filesystem state into a more robust state store if multiple machines or operators needed to manage deployments concurrently.

But I wouldn't start there.

I built this version first because I wanted to understand the state transitions, the artifacts, the failure modes, and the contracts between commands.

Once those are clear, replacing a directory with an artifact registry or replacing a local process with a container becomes a much more concrete engineering task.

The main takeaway is this:

A delivery system isn't just a collection of commands that build and deploy software. It's a system that preserves identity, verifies assumptions, tracks state, and recovers when things go wrong.

And the rule tying everything together is the one we started with:

**Build once, verify once, deploy the exact same artifact everywhere.**

## Before recording: three engineering fixes worth making

Your teaching material is strong, but I'd fix the following issues before presenting the code as a working implementation. These are especially useful because they demonstrate the difference between a happy-path demo and reliable delivery engineering.

1. Preserve rollback history correctly

The current `deployArtifactTo` updates `PREVIOUS_VERSION` every time it deploys. During an automatic rollback, that means the failed version can become the recorded previous version. A later rollback could therefore bring the broken release back.

Separate ordinary deployment history from recovery state. Preserve the last known-good version until a replacement has passed its health check, and only then commit the new deployment state.

2. Test the real application handler

The sample `TestHealthEndpoint` constructs its own handler instead of calling the handler registered by `app/main.go`. It can pass even if the real application's `/health` endpoint is broken.

Extract the application's HTTP handlers into a reusable function, such as `newHandler() http.Handler`, and have both the application and the test use it. Then the test verifies actual application behavior.

3. Make the artifact contract real

The packaging command currently allows an existing artifact version to be overwritten, and it doesn't check errors from `json.MarshalIndent`. Unique directory names alone don't guarantee immutable artifacts.

Reject existing versions, check every write and close operation, record a SHA-256 digest, and verify that digest before deployment. Also distinguish a successful HTTP health check from verification that the expected version is actually running.

One additional point to explain explicitly in the video: `harness build` runs tests against the source tree before compilation. That is a useful quality gate, but it isn't the same as independently testing the packaged binary. You can introduce artifact-level integration tests as a natural next step.

## Your presenter cheat sheet

Keep these five questions in front of you while recording. They will help you explain the why behind each implementation rather than merely reading code.

| When introducing… | Ask yourself… |
| --- | --- |
| Versioned builds | How will we identify and retrieve a particular build later? |
| The test gate | What conditions must be true before we allow a build to proceed? |
| Artifact packaging | What exactly are we approving for deployment? |
| Deployment and rollback | How do we know the change worked, and what happens if it didn't? |
| Promotion | How can we move a verified release without introducing a second build? |

The best tone for this video is curious and deliberate. Narrate the trade-offs as you make them, demonstrate failures rather than only successes, and distinguish clearly between the guarantees the code provides today and the ones a production system would still need to establish. That will teach your students how to think like engineers building delivery infrastructure, not just how to assemble a CLI.