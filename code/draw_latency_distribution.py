import matplotlib.pyplot as plt

#with open("/Users/ruiyuhan/IdeaProjects/proj3/latency_data1.txt", "r") as f:
with open("/Users/ruiyuhan/IdeaProjects/proj3/latency_data2.txt", "r") as f:
    latencies = [float(line.strip()) for line in f]

plt.hist(latencies, bins=1000, color='blue', edgecolor='black', alpha=0.7)  
plt.title("OpenGauss Response Time Distribution (ms)")  
#plt.title("PostgreSQL Response Time Distribution (ms)") 
plt.xlabel("Response Time (ms)")  
plt.ylabel("Frequency")

plt.xlim(0, 25) 
plt.show()