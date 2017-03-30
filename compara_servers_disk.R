data <- read.table("compara_servers_disk.txt", header=TRUE)

data2 <- data
data2[,2] <- data[,2] - data[,3] - data[,4]
data2[,3] <- data[,3] - data[,5]
data2[,c(2,3,4,5)] <- data2[,c(2,3,4,5)]/(1024 * 1024 * 1024)

cols=c("limegreen", "blue", "lightblue", "green")

png("compara_servers_disk.png")
par(xpd=T, mar=par()$mar+c(0,0,0,6))

b <- barplot(t(as.matrix(data2[,(c(2,3,5,4))])), col=cols, ylab="Disk space in Gb")
text(b, par("usr")[2] - 50, xpd=TRUE, srt=45, adj=1, labels=data2[,1])

legend(6, 2000, bty="n", xpd=TRUE, legend=rev(c("MyISAM-used", "InnoDB-used", "InnoDB-free", "Free")), fill=rev(cols))
dev.off()

