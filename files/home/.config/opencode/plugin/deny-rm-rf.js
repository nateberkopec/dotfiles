const RM_RF_PATTERN = /\brm\s+-[a-z]*r[a-z]*f[a-z]*\s+|\brm\s+-[a-z]*f[a-z]*r[a-z]*\s+/gi

export const RewriteRmRf = async () => {
  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") {
        return
      }

      const command = output?.args?.command ?? ""

      if (RM_RF_PATTERN.test(command)) {
        output.args.command = command.replace(RM_RF_PATTERN, "trash ")
      }
    }
  }
}
