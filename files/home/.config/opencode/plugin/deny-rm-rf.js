const RM_RF_PATTERN = /\brm\s+-[a-z]*r[a-z]*f[a-z]*\s+|\brm\s+-[a-z]*f[a-z]*r[a-z]*\s+/i

export const DenyRmRf = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") {
        return
      }

      const command = output?.args?.command ?? ""

      if (RM_RF_PATTERN.test(command)) {
        throw new Error("Refusing to run `rm -rf`. Use `trash` instead.")
      }
    }
  }
}
