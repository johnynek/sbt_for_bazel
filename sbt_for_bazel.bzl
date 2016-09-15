def _scala_major(ver):
  parts = ver.split(".")
  return "%s.%s" % (parts[0], parts[1])

def _clean(target_name):
  return target_name.replace("-", "_")

def _jar_path(target, version, scala):
  return "{target}/target/scala-{scala_version}/{target}_{scala_version}-{version}.jar".format(
      target=target,
      scala_version=_scala_major(scala),
      version=version)


def _sbt_jar(ctx):
  ctx.download_and_extract(
      ctx.attr.sbt_url,
      ctx.path("sbt"),
      ctx.attr.sbt_sha256,
      '',
      '')
  targets = " ".join([ "%s/package" % t for t in ctx.attr.targets ])

  result = ctx.execute(
      ["bash", "-c", """
set -ex
( cd {working_dir} &&
    if ! ( cd '{dir}' && {git} rev-parse --git-dir ) >/dev/null 2>&1; then
      rm -rf '{dir}'
      {git} clone '{remote}' '{dir}'
    fi
    cd '{dir}'
    {git} reset --hard {ref} || ({git} fetch && {git} reset --hard {ref})
    {git} clean -xdf
    {java} -jar {sbt_path} ++{scala} {targets})
""".format(
    dir=ctx.path("git"),
    git=ctx.which("git"),
    java=ctx.which("java"),
    working_dir=ctx.path("git").dirname,
    sbt_path=ctx.path("sbt/sbt/bin/sbt-launch.jar"), # we need to keep a private sbt dir
    remote=ctx.attr.git_remote,
    ref=ctx.attr.git_sha,
    targets=targets,
    scala=ctx.attr.scala_version,
    )])
  build_part = """
filegroup(
    name = "file",
    srcs = ['jar.jar'],
    visibility = ['//visibility:public']
)

java_import(
    name = "jar",
    jars = ['jar.jar'],
    visibility = ['//visibility:public']
)
"""
  ctx.file('WORKSPACE', "workspace(name = \"{name}\")\n".format(name=ctx.name))
  [ ctx.symlink("git/%s" % _jar_path(t, ctx.attr.version, ctx.attr.scala_version),
                "%s/jar.jar" % _clean(t)) for t in ctx.attr.targets ]
  [ ctx.file("%s/BUILD" % _clean(target), build_part) for target in ctx.attr.targets ]

sbt_jar = repository_rule(
    implementation=_sbt_jar,
    attrs={
        "sbt_url": attr.string(mandatory=True),
        "sbt_sha256": attr.string(mandatory=True),
        "git_remote": attr.string(mandatory=True),
        "git_sha": attr.string(mandatory=True),
        "targets": attr.string_list(mandatory=True, allow_empty=False),
        "scala_version": attr.string(mandatory=True),
        "version": attr.string(mandatory=True),
    })
