
args <- commandArgs(TRUE)
data <- read.table(args[1], header=TRUE, sep="\t")

data2 <- data
data2[,2] <- data[,2] - data[,3] - data[,4]
data2[,3] <- data[,3] - data[,5]
data2[,c(2,3,4,5)] <- data2[,c(2,3,4,5)]/(1024 * 1024 * 1024)

cols=c("mediumpurple", "blue", "lightblue", "green")

n_servers = dim(data)[1]
print(dim(data))
png(args[2], width=(420+50*n_servers), height=480)
par(xpd=TRUE, mar=par()$mar+c(0,0,0,9))

b <- barplot(t(as.matrix(data2[,(c(2,3,5,4))])), col=cols, ylab="Disk space in Gb")
text(b, par("usr")[2] - 50, xpd=TRUE, srt=45, adj=1, labels=data2[,1])

legend('topright', inset=c(-.8/n_servers,0), bty="n", xpd=TRUE, legend=rev(c("MyISAM-used", "InnoDB-used", "InnoDB-free", "Free")), fill=rev(cols))
dev.off()

