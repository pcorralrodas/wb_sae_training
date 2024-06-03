# Import libraries
import xgboost as xgb
import pandas as pd

# Set directory
#path = '/Users/hendersonhl/Desktop/Summer University/Application/'
path = 'C:/Users/WB378870/GitHub/wb_sae_training/00.Data/input/'

# Import data
data = pd.read_csv(path + 'data.csv', header = 0)
sample = data.dropna() 
y = sample['direct']
X = sample.drop(columns = ['municipality', 'direct', 'true'])  

# Implement XGBoost
model = xgb.XGBRegressor(objective='reg:squarederror', n_estimators=100,
        max_depth=6, eta=0.3)
model.fit(X, y)

# Generate poverty estimates
X_all = data.drop(columns = ['municipality', 'direct', 'true']) 
y_pred = model.predict(X_all)

# Import additional functions
from sklearn.model_selection import train_test_split
from sklearn.metrics import r2_score

# Create empty lists
r2_direct = []
r2_true = []

# Run loop
for i in range(100):
    # Split data and fit model
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.5)
    model.fit(X_train, y_train)
    # Get predicted and true values
    y_pred = model.predict(X_test)
    y_true = [sample['true'][i] for i in y_test.index]
    # Save R-squared results
    r2_direct.append(r2_score(y_test, y_pred))
    r2_true.append(r2_score(y_true, y_pred))
 
# Plot results  
import seaborn as sns
df = pd.DataFrame({'Direct': r2_direct, 'True': r2_true})
df = pd.melt(df)
b = sns.boxplot(data = df, x = "variable", y = "value", width = 0.5,
        color = "lightgray", linewidth = 1, showfliers = False)
b = sns.stripplot(data = df, x = "variable", y = "value", color = "crimson", 
        linewidth = 1, alpha = 0.2) 
b.set_ylabel("R-squared", fontsize = 14)
b.set_xlabel("Reference Measure", fontsize = 14)



