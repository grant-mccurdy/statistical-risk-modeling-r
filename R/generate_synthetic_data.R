source(file.path("R", "model_utils.R"))

ensure_project_dirs()
set.seed(20260623)

n_accounts <- 1400

clip <- function(x, lower, upper) {
  pmin(pmax(x, lower), upper)
}

account_id <- sprintf("ACCT-%04d", seq_len(n_accounts))

segment <- sample(
  c("SMB", "Mid-Market", "Enterprise", "Strategic"),
  size = n_accounts,
  replace = TRUE,
  prob = c(0.36, 0.34, 0.22, 0.08)
)

region <- sample(
  c("North", "South", "East", "West"),
  size = n_accounts,
  replace = TRUE,
  prob = c(0.27, 0.24, 0.25, 0.24)
)

implementation_complexity <- sample(
  c("Low", "Medium", "High"),
  size = n_accounts,
  replace = TRUE,
  prob = c(0.42, 0.40, 0.18)
)

segment_contract_mean <- c(
  "SMB" = 9.6,
  "Mid-Market" = 10.5,
  "Enterprise" = 11.25,
  "Strategic" = 12.0
)

contract_value <- round(exp(rnorm(
  n_accounts,
  mean = segment_contract_mean[segment],
  sd = 0.45
)), 0)

tenure_months <- clip(round(rgamma(n_accounts, shape = 2.4, scale = 13)), 1, 96)

segment_usage_shift <- c(
  "SMB" = -0.08,
  "Mid-Market" = 0.00,
  "Enterprise" = 0.05,
  "Strategic" = 0.08
)

complexity_usage_shift <- c(
  "Low" = 0.06,
  "Medium" = 0.00,
  "High" = -0.10
)

product_usage_rate <- clip(
  rbeta(n_accounts, shape1 = 5.4, shape2 = 2.8) +
    segment_usage_shift[segment] +
    complexity_usage_shift[implementation_complexity] +
    rnorm(n_accounts, sd = 0.06),
  0.03,
  0.99
)

active_seats_ratio <- clip(
  product_usage_rate * 0.72 +
    rbeta(n_accounts, shape1 = 3.0, shape2 = 3.5) * 0.35 +
    rnorm(n_accounts, sd = 0.08),
  0.02,
  0.99
)

training_completion_true <- clip(
  0.18 +
    0.55 * product_usage_rate +
    0.10 * active_seats_ratio -
    0.10 * (implementation_complexity == "High") +
    rnorm(n_accounts, sd = 0.12),
  0,
  1
)

support_lambda <- exp(
  0.25 +
    1.45 * (1 - product_usage_rate) +
    0.50 * (implementation_complexity == "High") +
    0.20 * (segment == "SMB")
)

support_tickets_90d <- pmin(rpois(n_accounts, lambda = support_lambda), 18)

avg_response_hours <- clip(
  exp(rnorm(
    n_accounts,
    mean = log(9 + 1.4 * support_tickets_90d + 7 * (implementation_complexity == "High")),
    sd = 0.45
  )),
  1,
  96
)

prior_incident_probability <- plogis(
  -2.0 +
    0.35 * support_tickets_90d +
    0.55 * (implementation_complexity == "High") -
    0.45 * product_usage_rate
)

prior_incident <- rbinom(n_accounts, size = 1, prob = prior_incident_probability)

missing_training_probability <- plogis(
  -3.0 +
    1.9 * (1 - product_usage_rate) +
    0.50 * (segment == "SMB") +
    0.35 * (implementation_complexity == "High")
)

training_completion_rate <- training_completion_true
training_completion_rate[
  rbinom(n_accounts, size = 1, prob = missing_training_probability) == 1
] <- NA_real_

linear_predictor <- -3.20 +
  1.55 * (1 - product_usage_rate) +
  1.10 * (1 - active_seats_ratio) +
  0.12 * support_tickets_90d +
  0.018 * avg_response_hours +
  0.65 * prior_incident +
  0.50 * (implementation_complexity == "High") +
  0.22 * (implementation_complexity == "Medium") +
  0.25 * (segment == "SMB") -
  0.15 * (segment == "Enterprise") -
  0.35 * training_completion_true -
  0.012 * tenure_months +
  0.08 * (log(contract_value) - mean(log(contract_value))) +
  0.55 * ((product_usage_rate < 0.45) & support_tickets_90d >= 5)

escalation_probability <- plogis(linear_predictor)
escalation_flag <- rbinom(n_accounts, size = 1, prob = escalation_probability)

account_risk <- data.frame(
  account_id = account_id,
  segment = factor(segment, levels = c("SMB", "Mid-Market", "Enterprise", "Strategic")),
  region = factor(region, levels = c("North", "South", "East", "West")),
  implementation_complexity = factor(
    implementation_complexity,
    levels = c("Low", "Medium", "High")
  ),
  contract_value = contract_value,
  tenure_months = tenure_months,
  product_usage_rate = round(product_usage_rate, 4),
  active_seats_ratio = round(active_seats_ratio, 4),
  training_completion_rate = round(training_completion_rate, 4),
  support_tickets_90d = support_tickets_90d,
  avg_response_hours = round(avg_response_hours, 2),
  prior_incident = prior_incident,
  escalation_flag = escalation_flag,
  stringsAsFactors = FALSE
)

write.csv(
  account_risk,
  file = file.path("data", "processed", "synthetic_account_risk.csv"),
  row.names = FALSE
)

event_rate <- mean(account_risk$escalation_flag)
missing_training_rate <- mean(is.na(account_risk$training_completion_rate))

message("Generated data/processed/synthetic_account_risk.csv")
message("Rows: ", nrow(account_risk))
message("Escalation rate: ", format_pct(event_rate))
message("Missing training completion: ", format_pct(missing_training_rate))
